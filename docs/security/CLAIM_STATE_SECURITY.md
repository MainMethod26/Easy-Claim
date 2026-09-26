# Claim State Security

## Original implementation (before the `cyber` branch)

There was no state. Every `/claims/*` route in `backend/src/endpoints/claims.ts` returned fixed JSON:

- `initiate` returned `claim_${Date.now()}` (enumerable) and wrote nothing.
- `submit` returned `submitted` for **any** claim ID, any number of times.
- `timeline` always returned Submitted/Verified as done.
- `appeal` always returned `appealed`.

Nothing prevented a client from "submitting" someone else's claim or skipping stages.

## Implemented state machine

The source is `backend/src/security/claimStateMachine.ts` (`TRANSITIONS`, `checkTransition`). Anything not listed below is illegal.

| From | To | Allowed actor |
|---|---|---|
| Draft | Submitted | CUSTOMER |
| Draft | Withdrawn | CUSTOMER |
| Submitted | Verified | ASSESSOR, MANAGER |
| Submitted | Withdrawn | CUSTOMER |
| Verified | Screening | ASSESSOR, MANAGER |
| Verified | Withdrawn | CUSTOMER |
| Screening | Review | ASSESSOR, MANAGER |
| Screening | Info Needed | ASSESSOR, MANAGER |
| Screening | Withdrawn | CUSTOMER |
| Review | Decision | ASSESSOR, MANAGER |
| Review | Info Needed | ASSESSOR, MANAGER |
| Review | Withdrawn | CUSTOMER |
| Info Needed | Screening | CUSTOMER |
| Info Needed | Withdrawn | CUSTOMER |
| Info Needed | Expired | SYSTEM |
| Decision | Paid | MANAGER |
| Decision | Appeal | CUSTOMER |
| Appeal | Review | MANAGER |
| Paid / Withdrawn / Expired | — (terminal) | — |

`checkTransition` returns one of three failure reasons, which the API maps to responses:

- `unknown_stage` → HTTP 409
- `illegal_transition` → HTTP 409
- `role_not_permitted` → HTTP 403

Every rejection writes a `claim.transition_rejected` audit event.

**Phase 1 update:** the state machine table above is unchanged in Phase 1. Two further rejections are produced by the API layer rather than by `checkTransition`, and both are audited as `claim.transition_rejected` with the reason named:

- `stale_state` → HTTP 409, from `transitionClaim` when the conditional UPDATE changed 0 rows (see "Replay and race protection")
- `not_approved` → HTTP 409, from `POST /claims/:claimId/pay` when the claim is in `Decision` but `status` is not `Approved` (`backend/src/endpoints/claimsInsurer.ts`)

## Design decisions

- **`Draft` was added**, because `POST /claims/initiate` already created a draft before submission. Draft claims are editable; Submitted claims are not.
- **Title-case stage strings** (`'Info Needed'`, `'Review'`) are used instead of SUBMITTED/VERIFIED because `seed_sa_data.sql` and `frontend/src/types/index.ts` (`ClaimSummary.stage`) already use them, so no data migration is needed.
- **ADMIN has no transitions**, for separation of duties.
- **Paid is MANAGER-only.** `SYSTEM` is used only for scheduled expiry and can never be a request actor, because `resolveActor` only accepts the four real roles.
- **`status`** (Pending/Approved/Rejected) is the decision outcome, is server-set, and can't be written by clients (strict schemas).
  - **Phase 1 update:** `status` is now set by exactly one route, `POST /claims/:claimId/decide`, whose strict body is `{ outcome: 'Approved' | 'Rejected' }` (`decideSchema` in `backend/src/security/validation.ts`). The value is passed to `transitionClaim(..., { status: outcome })` and written in the same `UPDATE` statement as the stage change, so a claim can never be in `Decision` with an unset outcome. Any other key (`amount`, `status`, `approvedBy`) or value (`Paid`) is rejected with 400 (TESTED/PASSED: `test/tenant.test.ts` "decide rejects invalid or extra fields").
- **Phase 1: tenant boundary on top of role.** Insurer roles may act on a claim only when `actor.tenantId === claim.tenant_id` (non-null) and the claim is no longer a `Draft` (`isTenantInsurer()` in `backend/src/security/claimAccess.ts`). The role table above therefore reads "ASSESSOR/MANAGER **of the claim's tenant**". Customers are platform-level and are matched by `claims.user_id` only.

## Replay and race protection

`transitionClaim` (`backend/src/security/claimAccess.ts`) runs:

```sql
UPDATE claims SET stage = ?, updated_at = ? WHERE id = ? AND stage = ?
```

The final `stage = ?` is the stage the caller read. If another request already moved the claim, `meta.changes` is 0 and the API returns 409 `stale_state`. A replayed or duplicate submit gets 409; this was verified live.

### Phase 1 update: what `transitionClaim` does now

`transitionClaim(c, claim, to, opts)` is still the only code path that changes `claims.stage`. In order:

1. **Owner / tenant guard (defence in depth).** Even though every caller has already gone through `loadAuthorizedClaim`, the function re-checks that the actor is the owning CUSTOMER (`claim.user_id === actor.id`) or a tenant insurer (`isTenantInsurer(actor, claim)`). Failure → 403 `forbidden` and an `authz.claim_access_denied` audit row with `{ mode: 'transition', exists: true, reason: 'transition_guard' }`.
2. **State machine.** `checkTransition(claim.stage, to, actor.role)`; failures map to 403/409 as listed above and are audited as `claim.transition_rejected`.
3. **One D1 batch (a transaction) with two statements:**
   - `UPDATE claims SET stage = ?, updated_at = ? WHERE id = ? AND stage = ?` (or, when `opts.status` is given by `/decide`, `UPDATE claims SET stage = ?, status = ?, updated_at = ? WHERE id = ? AND stage = ?`), bound to the stage the caller read;
   - `INSERT INTO audit_events (...) SELECT ... WHERE changes() = 1` for the `claim.stage_changed` row (`auditStatement(..., { onlyIfPreviousChanged: true })` in `backend/src/security/audit.ts`). SQLite's `changes()` refers to the statement immediately before it in the same batch, so the audit row exists only when the stage change applied, and the stage change never applies without its audit row.
4. **Lost race / replay.** If the UPDATE reports `meta.changes !== 1`, the gated INSERT has already written nothing; the function then writes a `claim.transition_rejected` row with `reason: 'stale_state'` and returns 409 `stale_state`.

TESTED/PASSED: `test/audit.test.ts` "a stage-change audit row is written only when the stage change applied (same transaction)" reproduces the batch with a stale and a fresh precondition. This closes Phase 0 handoff BACKEND-SEC-013.

### Phase 1 update: screening write precondition in SQL

`PATCH /claims/:claimId/screening` (`backend/src/endpoints/claims.ts`) checks the stage after `loadAuthorizedClaim` (409 `claim_not_editable` unless `Draft` or `Info Needed`) **and** repeats the precondition in the write itself:

```sql
UPDATE claims SET cause_of_loss = ?, incident_date = ?, updated_at = ? WHERE id = ? AND stage IN ('Draft', 'Info Needed')
```

`meta.changes !== 1` → 409 `claim_not_editable`, so a transition that lands between the read and the write cannot let a customer edit a claim that is already under review. When the claim was in `Info Needed`, the same request then calls `transitionClaim(c, claim, 'Screening')`.

## Reachability today

Phase 0 state (kept for history): only `submit`, `screening` (Info Needed → Screening) and `appeal` were reachable; every insurer transition, Paid, Withdrawn and Expired had no endpoint.

### Phase 1 update: route → transition → role

All routes are under `/api/v1/claims` (mounted in `backend/src/index.ts`; customer routes in `backend/src/endpoints/claims.ts`, insurer routes in `backend/src/endpoints/claimsInsurer.ts`). Every row below goes through `requireActor` → coarse `requireRole` → strict zod validation → `loadAuthorizedClaim` (load → tenant → ownership → mode) → `transitionClaim` → audit. "Role" is what the state machine enforces; the coarse gate in front of the insurer routes is `requireRole('ASSESSOR', 'MANAGER')` and is resource-independent, so a 403 from it cannot be used as a cross-tenant existence oracle.

| Route | Transition | Role | Access mode | Extra precondition |
|---|---|---|---|---|
| `POST /:claimId/submit` | Draft → Submitted | CUSTOMER | `owner-write` | `cause_of_loss` and `incident_date` present, else 422 `screening_incomplete` |
| `POST /:claimId/verify` | Submitted → Verified | ASSESSOR, MANAGER | `insurer` | — |
| `POST /:claimId/screen` | Verified → Screening | ASSESSOR, MANAGER | `insurer` | — |
| `POST /:claimId/review` | Screening → Review | ASSESSOR, MANAGER | `insurer` | — |
| `POST /:claimId/review` | Appeal → Review | MANAGER only | `insurer` | ASSESSOR gets 403 (TESTED/PASSED STATE-005) |
| `POST /:claimId/request-info` | Screening → Info Needed, Review → Info Needed | ASSESSOR, MANAGER | `insurer` | — |
| `PATCH /:claimId/screening` | Info Needed → Screening | CUSTOMER | `owner-write` | stage `IN ('Draft','Info Needed')` repeated in SQL; transition only when the stage read was `Info Needed` |
| `POST /:claimId/decide` `{outcome}` | Review → Decision | ASSESSOR, MANAGER | `insurer` | strict body `outcome ∈ {Approved, Rejected}`; written to `claims.status` in the same UPDATE |
| `POST /:claimId/pay` | Decision → Paid | MANAGER only | `insurer` | `status = 'Approved'`, else 409 `not_approved` (audited); state transition only, no payment execution |
| `POST /:claimId/appeal` `{reason}` | Decision → Appeal | CUSTOMER | `owner-write` | `status = 'Rejected'`, else 409 `not_appealable`; `reason` is validated (1–2000 chars) but NOT persisted (NOT IMPLEMENTED) |
| — | Draft / Submitted / Verified / Screening / Review / Info Needed → Withdrawn | CUSTOMER | — | **NOT IMPLEMENTED**: no endpoint; enforced only by `checkTransition` |
| — | Info Needed → Expired | SYSTEM | — | **NOT IMPLEMENTED**: no scheduled job; `SYSTEM` can never be a request actor |

ADMIN reaches none of these: the insurer routes and `GET /claims` return 403 (audited `authz.role_denied`), and the read routes (`timeline`, `decision`) return 404 via `loadAuthorizedClaim` (reason `role`). TESTED/PASSED: `test/tenant.test.ts` TENANT-001b, RBAC-002.

Live evidence for the full `Submitted → Verified → Screening → Review → Decision → Paid` path, the 409 for `pay` before a decision, the 403 for an assessor `pay`, and the 409 replay of `pay` is in `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` ("Happy path", ATTACK-P1-006, ATTACK-P1-008).

## Open decisions (DECISION REQUIRED)

| Question | Current behaviour |
|---|---|
| **Appeal cycle is unbounded.** | `Decision(Rejected) → Appeal → Review → Decision(Rejected) → Appeal → …` is legal indefinitely. `POST /appeal` allows exactly one appeal per `Decision` stage (a second call while in `Appeal` gets 409, TESTED/PASSED `test/claimLifecycle.test.ts`), but nothing counts appeals across cycles. No appeal count is stored; only the audit trail records them. |
| **Assessors may decide.** | `Review → Decision` is open to ASSESSOR and MANAGER (unchanged from Phase 0). Whether decisions should be MANAGER-only is not decided; see DECISION_SECURITY.md. |
| **Separation of duties between decide and pay.** | The same MANAGER may call `/decide` and then `/pay` on the same claim (that is exactly what STATE-001 and the live happy path do). No "payer ≠ decider" check exists; see PAYOUT_SECURITY.md. |
| **Withdrawn / Expired.** | Edges exist in the state machine only. Adding them means a customer endpoint (Withdrawn) and a scheduled/cron job acting as `SYSTEM` (Expired); both must go through `transitionClaim`. |

## Test coverage (TESTED/PASSED)

- `backend/test/stateMachine.test.ts` covers:
  - 12 legal transitions
  - 8 illegal jumps, including Submitted→Paid, Screening→Paid, Screening→Decision (skipping review) and exiting terminal states
  - 7 role violations, including CUSTOMER→Decision, CUSTOMER→Paid, ASSESSOR→Paid and ADMIN→anything
  - unknown stages
  - invariants that ADMIN appears nowhere and Paid is MANAGER-only
- `backend/test/claimLifecycle.test.ts` covers:
  - end-to-end initiate → screening → submit, with audit rows written
  - submit before screening returns 422
  - double submit returns 409
  - submitting or editing a Review claim returns 409
  - appealing an Approved decision returns 409
  - appealing a Rejected decision succeeds once, then returns 409
  - a non-active policy returns 422

### Phase 1 update (TESTED/PASSED, `cd backend && npm test`: 12 files, 175 passed, 1 todo)

- `backend/test/tenant.test.ts` (over HTTP with verified JWTs):
  - STATE-001: full path Submitted → Verified → Screening → Review → Decision (Approved) → Paid with the right tenant and roles; six `claim.stage_changed` rows in order, each carrying a `request_id`; timeline shows every stage completed with a date
  - STATE-002: correct role, wrong tenant → 404 and stage unchanged
  - STATE-003: correct tenant, ASSESSOR calls `/pay` → 403, audited `role_not_permitted`
  - STATE-004: skipping stages (`screen`, `review`, `decide`, `pay` from Submitted) → 409, stage unchanged
  - STATE-005: Rejected decision → `/pay` 409 `not_approved`; customer appeals → Appeal; ASSESSOR `/review` 403, MANAGER `/review` 200
  - STATE-006: `request-info` → Info Needed; customer `PATCH /screening` → back to Screening
  - TENANT-002 / TENANT-002b: every insurer route on another tenant's claim → 404, zero `claim.stage_changed` rows, all denials audited `cross_tenant`
  - RBAC-001 / RBAC-002: CUSTOMER and ADMIN on insurer routes → 403, stage unchanged
- `backend/test/audit.test.ts`: the batch's `changes()`-gated audit INSERT (stale precondition → 0 rows and no audit row; fresh → both land)
- `backend/test/stateMachine.test.ts`: unchanged (state machine unchanged)
- NOT TESTED: a dedicated double-`/decide` case (the state machine has no `Decision → Decision` edge, so it is rejected as `illegal_transition`, but no test exercises it directly); Withdrawn/Expired over HTTP (no endpoint/job exists)
