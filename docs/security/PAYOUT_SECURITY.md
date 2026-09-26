# Payout Security

> **Phase 3 update (2026-09-26).** A **simulated** payout now exists (`payouts` insert-only table,
> `status = 'simulated'`, no money moves). The customer supplies the claimed amount and destination
> only while the claim is Draft / Info Needed (`PUT /payout-details`; account number stored as
> SHA-256 + last 4); after submission changes are refused and audited. `POST /pay` (MANAGER of the
> tenant) accepts no body — any client field is refused (400) and audited — pays exactly the recorded
> approved amount, refuses if the destination no longer matches the decision-time snapshot
> (409 `destination_mismatch`), and allows one payout per claim (`UNIQUE`, 409 `already_paid`; an
> identical `Idempotency-Key` replays the same payout). Not implemented: payment rail, destination
> verification / step-up auth for legitimate changes, second approver, separation of duties. Full
> detail: `docs/phase-reports/PHASE_03_REPORT.md`. The sections below describe the state before
> Phase 3 and remain as history.

## Actual state

**Payment execution is NOT IMPLEMENTED.** There is:

- ~~no payout endpoint~~ **Phase 1 update:** a `Decision → Paid` state-transition endpoint exists (below); it moves no money;
- no payout table;
- no payment provider integration;
- no bank-detail handling;
- no amount anywhere in the model (no decision record).

The `Paid` stage in `src/security/claimStateMachine.ts` is unchanged: `Decision → Paid` is allowed **only for MANAGER**, and CUSTOMER, ASSESSOR and ADMIN are rejected (TESTED/PASSED in `test/stateMachine.test.ts`).

### Phase 1 update: `POST /api/v1/claims/:claimId/pay` (state transition only)

`src/endpoints/claimsInsurer.ts`, in order:

1. `requireActor` (verified JWT) → `requireRole('ASSESSOR', 'MANAGER')` (CUSTOMER/ADMIN → 403, audited `authz.role_denied`) → strict `claimId` validation.
2. `loadAuthorizedClaim(c, claimId, 'insurer')`: claim must belong to the actor's tenant and not be a Draft, else 404 `not_found` (audited `authz.claim_access_denied`, e.g. `cross_tenant`).
3. `checkTransition(claim.stage, 'Paid', actor.role)` as a pre-check. Only if the edge is legal **and** the role is MANAGER does the approval precondition run: `claim.status !== 'Approved'` → 409 `not_approved`, audited `claim.transition_rejected { from, to: 'Paid', reason: 'not_approved' }`. (Role and legality are checked first so an ASSESSOR gets the same 403 whether or not the decision was approved.)
4. `transitionClaim(c, claim, 'Paid')`: owner/tenant re-check, state machine (ASSESSOR → 403 `forbidden`, audited `role_not_permitted`; wrong stage → 409 `illegal_transition`), then the one-batch conditional `UPDATE ... WHERE id = ? AND stage = 'Decision'` plus the `changes()`-gated audit row `claim.stage_changed { from: 'Decision', to: 'Paid' }`. A lost race → 409 `stale_state` (audited).
5. Response `{ status: 'transitioned', claimId, from: 'Decision', to: 'Paid' }`. No amount, no destination, no reference number, no provider call.

`Paid` is terminal, so a replayed `/pay` gets 409 `illegal_transition`.

TESTED/PASSED (`test/tenant.test.ts`): STATE-001 (MANAGER pays an Approved claim → 200, audited with `request_id`), STATE-003 (ASSESSOR → 403, audited), STATE-004 (`/pay` from `Submitted` → 409), STATE-005 (Rejected decision → 409 `not_approved`), TENANT-002/002b (other tenant's MANAGER → 404, no change), RBAC-001 (CUSTOMER → 403).

Live evidence (`docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log`, "Happy path" block): `[pay before decision (manager A)]` 409 `illegal_transition`; `[pay by assessor A]` 403; `[pay by manager A]` 200; `[pay again (replay)]` 409 `illegal_transition`. ATTACK-P1-008 in the same log repeats the assessor case on tenant B's approved claim: `[assessor B pay]` 403.

**Related money-adjacent stub:** `POST /api/v1/profile/mandates/cancel` (`src/endpoints/identity.ts`) represents cancelling a debit-order mandate. It:

- now requires `CUSTOMER`;
- writes the audit event `mandate.cancel_requested`;
- **does nothing else**: no mandate data exists, it has no request body, and ownership can't be checked.

`GET /profile/mandates/:tenantId/check` returns `{active:true}` for any `tenantId` (stub, unscoped). **Phase 1 update:** still a stub; the `:tenantId` parameter is ignored and is not compared with the real `tenants` table introduced by migration `0003_tenants.sql`.

## Planned controls

| Control | Requirement | Status |
|---|---|---|
| Payout authorization | MANAGER only, same org, claim in `Decision` with status Approved | **IMPLEMENTED in Phase 1 for the state transition** (`/pay`: MANAGER via state machine, same tenant via `loadAuthorizedClaim('insurer')`, `Decision` + `Approved` precondition). TESTED/PASSED. No payment is executed, so "authorization" here authorizes a status change only. |
| Separation of duties | Payer ≠ decider; above a threshold, two distinct MANAGERs | NOT IMPLEMENTED — **DECISION REQUIRED.** The same MANAGER decides and pays in STATE-001 and in the live happy path. Enforcing it needs the decider's id (from the `claim.stage_changed { to: 'Decision' }` row or a future `claim_decisions` record) compared with the payer at `/pay` time, and at least two MANAGER identities per tenant (the demo seed has one). |
| Amount integrity | Amount taken from the `claim_decisions` record, never from the payout request body | PLANNED — `/pay` accepts no body and no amount exists |
| Destination verification | Bank account verified against the policyholder (AVS-style account verification) before first use | PLANNED |
| Destination change protection | Step-up auth, a cooling-off period (e.g. 24 h) before a new account can receive funds, and a notification to the old contact channel | PLANNED |
| Replay / duplicate protection | Idempotency key per payout plus a unique constraint on `(claim_id)` for full payouts; the conditional `UPDATE ... WHERE stage='Decision'` already prevents double transition | PARTIAL — transition guard IMPLEMENTED and audited (`stale_state`, replay → `illegal_transition`; TESTED/PASSED and verified live). Idempotency key / unique payout row PLANNED (no payout row exists). |
| Step-up authentication | Re-auth or MFA for payout release and destination change | PLANNED. Phase 1 replaced BACKEND-SEC-001 with verified HS256 bearer JWTs (staff tokens ≤ 8 h), but there is no MFA, no re-auth and no revocation. |
| High-value approval | Threshold from versioned config; dual approval above it | PLANNED (no amount) |
| Audit | `payout.requested`, `payout.approved`, `payout.released`, `payout.failed`, `payout.destination_changed`, with masked account numbers only | PARTIAL — the transition is audited as `claim.stage_changed { to: 'Paid' }` with `actor_id`, `actor_tenant_id` and `request_id`; denials as `claim.transition_rejected` (`not_approved`, `role_not_permitted`, `illegal_transition`, `stale_state`). Dedicated `payout.*` events PLANNED with payment execution. |
| Notification | Customer notified on payout and on destination change | PLANNED |
| Mandate cancel | Ownership check against a real mandate record, step-up, audit (audit already done) | PARTIAL — unchanged in Phase 1 |

For the hackathon, if a payout is shown in a demo it should be **simulated**: move to `Paid` through `transitionClaim` as a MANAGER, with an audit event, and no real money movement. It should be labelled as simulated.

**Phase 1 update:** `POST /claims/:claimId/pay` is exactly that simulated path and nothing more. Demo narration must say "state transition to Paid", not "payout", and must not imply funds, amounts or destinations exist.
