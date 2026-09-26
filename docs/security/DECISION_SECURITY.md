# Decision Security

> **Phase 5 update (2026-09-26).** Every decision is now signed with ML-DSA-65 (NIST FIPS 204) over a canonical
> bundle (outcome, amounts, destination hash, evidence digest, screening signal, actor, time, reason, rules version);
> `GET /claims/:id/decision/verify` checks it and `/pay` refuses any decision that does not verify. See
> `docs/security/PQC_DECISION_INTEGRITY.md` and `docs/phase-reports/PHASE_05_REPORT.md`.

> **Phase 3 update (2026-09-26).** Decisions are now MANAGER-only and recorded in the insert-only
> `claim_decisions` table (who, what, when, why, previous stage, claimed/approved amounts, destination
> snapshot, request id, `rules_version = phase3-manual-v1`), written in the same D1 batch as the
> `Review → Decision` transition. `POST /decide` takes `{ outcome, reason, approvedAmountCents? }`;
> an approval requires payout details and may not exceed the claimed amount. `GET /decision` returns
> the record. Reserved for later phases: `evidence_digest` (Phase 2), `risk_signal` (advisory
> screening, never a transition), `integrity_signature` (ML-DSA). Full detail, attack results and
> limitations: `docs/phase-reports/PHASE_03_REPORT.md`. The sections below describe the state before
> Phase 3 and remain as history.

## Actual state

Phase 0 (kept for history): no endpoint recorded a decision; outcomes existed only in seed data.

### Phase 1 update: `POST /api/v1/claims/:claimId/decide` exists (outcome only)

`src/endpoints/claimsInsurer.ts`:

- gate order: `requireActor` (verified JWT) → `requireRole('ASSESSOR', 'MANAGER')` (403 `forbidden`, audited `authz.role_denied`) → strict param + body validation → `loadAuthorizedClaim(c, claimId, 'insurer')` (claim must belong to the actor's tenant and not be a `Draft`, else 404 `not_found`, audited `authz.claim_access_denied`) → `transitionClaim(c, claim, 'Decision', { status: outcome, details: { outcome } })`;
- body is `decideSchema` = `{ outcome: 'Approved' | 'Rejected' }`, `.strict()` (`src/security/validation.ts`). `outcome: 'Paid'`, or any extra key such as `amount`, → 400 `validation_failed` (TESTED/PASSED `test/tenant.test.ts` "decide rejects invalid or extra fields");
- the outcome is written to `claims.status` **in the same `UPDATE` statement as the stage change** (`UPDATE claims SET stage = ?, status = ?, updated_at = ? WHERE id = ? AND stage = ?` in `transitionClaim`, bound to `'Decision'`, the outcome, the claim id and the `Review` stage that was read), inside the one D1 batch that also inserts the `changes()`-gated audit row `claim.stage_changed { from: 'Review', to: 'Decision', outcome }`;
- response: `{ status: 'transitioned', claimId, from: 'Review', to: 'Decision', outcome }`;
- what is **not** recorded: amount, reason code or note, rules/model version, evidence hashes, screening result. There is no `claim_decisions` table (PLANNED, backend). The only durable decision data is `claims.status` plus the audit row.

`GET /api/v1/claims/:claimId/decision` is unchanged: owning CUSTOMER or tenant insurer via `loadAuthorizedClaim(..., 'read')`, anyone else 404; returns `claims.status` when `stage` is `Decision` or `Paid`, otherwise `pending`. Cross-tenant read of a decision → 404 (TESTED/PASSED TENANT-003).

Live evidence (`docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log`): `[decide Approved (manager A)]` 200; `[customer decide]` 403 (ATTACK-P1-007); `[cross-tenant decide]` 404 with stage unchanged (ATTACK-P1-006).

Every other body-taking route uses a `.strict()` schema (`src/security/validation.ts`), so client-supplied `status`/`decision`/`approvedBy`/`stage`/`tenant_id` are rejected with 400; TESTED/PASSED for `PATCH /:claimId/screening` and `POST /initiate` in `test/massAssignment.test.ts`. The state machine (unchanged) restricts `Review → Decision` to ASSESSOR/MANAGER and forbids CUSTOMER and ADMIN (`test/stateMachine.test.ts`; over HTTP: RBAC-001, RBAC-002).

## Who may decide

| Rule | Status |
|---|---|
| Only ASSESSOR or MANAGER may decide | IMPLEMENTED in `checkTransition` **and over HTTP in Phase 1** (`/decide`: coarse gate + state machine). TESTED/PASSED: customer → 403 (RBAC-001), admin → 403 (RBAC-002). **DECISION REQUIRED:** the state machine lets an ASSESSOR decide as well as a MANAGER; whether decisions should be MANAGER-only (or MANAGER-only above a threshold) has not been decided. Changing it is a one-line edit of `TRANSITIONS.Review.Decision` in `claimStateMachine.ts`. |
| Decider must be in the same insurer org as the claim | **IMPLEMENTED in Phase 1** as the tenant boundary: `loadAuthorizedClaim(..., 'insurer')` requires `actor.tenantId === claim.tenant_id` and `transitionClaim` re-asserts it. TESTED/PASSED: tenant B manager `/decide` on a tenant A claim → 404, stage unchanged (TENANT-002, TENANT-002b). |
| Decider must not be the claimant | PARTIAL — a CUSTOMER token cannot decide and a staff token cannot own a claim (roles are exclusive per token; customers carry no `tenant_id`). There is no linkage between a staff `sub` and a customer `sub`, so a person holding both identities is not detected. NOT IMPLEMENTED beyond role separation. |
| Above a configurable amount threshold, MANAGER only (or dual approval) | NOT IMPLEMENTED — no amount exists anywhere in the model |
| Claim must be in `Review`; any other stage gets 409 | IMPLEMENTED in the state machine and TESTED/PASSED over HTTP (STATE-004: `/decide` on a `Submitted` claim → 409 `illegal_transition`) |
| Same decision cannot be applied twice | IMPLEMENTED by the state machine (no `Decision → Decision` edge → 409 `illegal_transition`) and by the conditional UPDATE (concurrent request → 409 `stale_state`, audited). NOT TESTED as a dedicated double-`/decide` case. |
| Re-decision after appeal | IMPLEMENTED path: `Decision(Rejected) → Appeal` (CUSTOMER) `→ Review` (MANAGER only) `→ Decision` (ASSESSOR/MANAGER) overwrites `claims.status`; the previous outcome survives only in the audit trail. **DECISION REQUIRED:** the appeal cycle is unbounded (see CLAIM_STATE_SECURITY.md). |
| Separation of duties: decider ≠ payer | NOT IMPLEMENTED — the same MANAGER may call `/decide` and then `/pay` (STATE-001 and the live happy path do exactly this). **DECISION REQUIRED** (see PAYOUT_SECURITY.md). |
| AI/OCR output can never set a decision directly | PLANNED (AI_SECURITY.md). Today no AI/OCR component exists; `claims.status` is written only by `transitionClaim` from a validated `/decide` body. |

## Decision record (PLANNED, backend)

**Phase 1 status: NOT IMPLEMENTED.** A decision must be reconstructable later. Add a `claim_decisions` table (insert-only, same trigger pattern as `audit_events`). Today the reconstructable data is limited to `claims.status` and the `claim.stage_changed` audit row (`actor_id`, `actor_role`, `actor_tenant_id`, `request_id`, `occurred_at`, `details.outcome`).

| Field | Purpose |
|---|---|
| `claim_id` | Which claim |
| `decision` | `Approved` / `Rejected` / `Partial` |
| `amount_cents` | Integer amount, never floats |
| `actor_id`, `actor_role` | Who decided, taken from the resolved actor, never from the body |
| `decided_at` | Server timestamp |
| `rules_version` | Version of screening/fraud rules applied |
| `model_version` | Only if an AI/OCR signal was used |
| `evidence_hashes` | JSON array of `evidence.sha256` values considered |
| `screening_result` | Structured signal (risk flags and score), not free text from AI |
| `reason` | Required text; a reason code plus a note |

## Required from the backend team

Phase 1 update: items are annotated with what now exists.

1. ~~Add `POST /claims/:claimId/decision`~~ **PARTIAL:** the route exists as `POST /claims/:claimId/decide` with `requireRole('ASSESSOR','MANAGER')`, `loadAuthorizedClaim(...,'insurer')` (which is the org/tenant check) and the strict schema `{ outcome }`. Extending the schema to `{ outcome, amountCents, reasonCode, note }` is PLANNED; keep it `.strict()`.
2. ~~In one D1 batch: insert into `claim_decisions`, set `claims.status`, and call `transitionClaim`~~ **PARTIAL:** `transitionClaim(c, claim, 'Decision', { status })` already sets `claims.status` in the same statement and batch as the stage change. Adding the `claim_decisions` INSERT to that batch (with the same `changes() = 1` gate as the audit row) is PLANNED.
3. Write the `claim.decision_recorded` audit event (IDs, amount and reason code only). **NOT IMPLEMENTED** — today the outcome is carried in `claim.stage_changed.details.outcome`.
4. Tests:
   - a customer deciding gets 403 — TESTED/PASSED (RBAC-001)
   - deciding outside Review gets 409 — TESTED/PASSED (STATE-004)
   - a body containing an extra field (`amount`) or an out-of-range `outcome` gets 400 — TESTED/PASSED (`test/tenant.test.ts`); `approvedBy` specifically NOT TESTED on this route (rejected by the same `.strict()` schema)
   - a double decision gets 409 — NOT TESTED as a dedicated case (enforced by the state machine)
   - cross-tenant decide gets 404 with no state change — TESTED/PASSED (TENANT-002b)
   - the record contains the evidence hashes — BLOCKED (no evidence storage, no decision record)
5. **DECISION REQUIRED** before the record is designed: may assessors decide, or managers only; is decider ≠ payer enforced (and how, given a single MANAGER per demo tenant); is the appeal count capped.
