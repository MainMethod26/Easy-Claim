# Payout Security

## Actual state

**Payout is NOT IMPLEMENTED.** There is:

- no payout endpoint;
- no payout table;
- no payment provider integration;
- no bank-detail handling.

The only payout-related code is the `Paid` stage in `backend/src/security/claimStateMachine.ts`. `Decision → Paid` is allowed **only for MANAGER**, and CUSTOMER, ASSESSOR and ADMIN are rejected (TESTED/PASSED in `test/stateMachine.test.ts`). No endpoint performs this transition.

**Related money-adjacent stub:** `POST /api/v1/profile/mandates/cancel` (`backend/src/endpoints/identity.ts`) represents cancelling a debit-order mandate. It:

- now requires `CUSTOMER`;
- writes the audit event `mandate.cancel_requested`;
- **does nothing else**: no mandate data exists, it has no request body, and ownership can't be checked.

`GET /profile/mandates/:tenantId/check` returns `{active:true}` for any `tenantId` (stub, unscoped).

## Planned controls

| Control | Requirement | Status |
|---|---|---|
| Payout authorization | MANAGER only, same org, claim in `Decision` with status Approved | PARTIAL (role rule in the state machine only) |
| Separation of duties | Payer ≠ decider; above a threshold, two distinct MANAGERs | PLANNED |
| Amount integrity | Amount taken from the `claim_decisions` record, never from the payout request body | PLANNED |
| Destination verification | Bank account verified against the policyholder (AVS-style account verification) before first use | PLANNED |
| Destination change protection | Step-up auth, a cooling-off period (e.g. 24 h) before a new account can receive funds, and a notification to the old contact channel | PLANNED |
| Replay / duplicate protection | Idempotency key per payout plus a unique constraint on `(claim_id)` for full payouts; the conditional `UPDATE ... WHERE stage='Decision'` already prevents double transition | PARTIAL (transition guard exists) |
| Step-up authentication | Re-auth or MFA for payout release and destination change | PLANNED (depends on real auth, BACKEND-SEC-001) |
| High-value approval | Threshold from versioned config; dual approval above it | PLANNED |
| Audit | `payout.requested`, `payout.approved`, `payout.released`, `payout.failed`, `payout.destination_changed`, with masked account numbers only | PLANNED |
| Notification | Customer notified on payout and on destination change | PLANNED |
| Mandate cancel | Ownership check against a real mandate record, step-up, audit (audit already done) | PARTIAL |

For the hackathon, if a payout is shown in a demo it should be **simulated**: move to `Paid` through `transitionClaim` as a MANAGER, with an audit event, and no real money movement. It should be labelled as simulated.
