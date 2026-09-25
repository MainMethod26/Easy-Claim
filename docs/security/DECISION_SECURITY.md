# Decision Security

## Actual state

**No endpoint records a decision.** `GET /api/v1/claims/:claimId/decision` (`backend/src/endpoints/claims.ts`):

- requires the owning CUSTOMER or an ASSESSOR/MANAGER (`loadAuthorizedClaim(..., 'read')`); anyone else gets 404;
- returns `claims.status` when `stage` is `Decision` or `Paid`, otherwise `pending`.

Decision outcomes today exist only in seed data (for example `claim_sanlam_102`: Decision/Approved). Nothing in the API can set `status`, and strict schemas reject client-supplied `status`/`decision`/`approvedBy` (`test/massAssignment.test.ts`).

The state machine already restricts `Review → Decision` to ASSESSOR/MANAGER and forbids CUSTOMER and ADMIN (`test/stateMachine.test.ts`).

## Who may decide (planned)

| Rule | Status |
|---|---|
| Only ASSESSOR or MANAGER may decide | IMPLEMENTED in `checkTransition`. No endpoint yet |
| Decider must be in the same insurer org as the claim | NOT IMPLEMENTED (no org model) |
| Decider must not be the claimant | PLANNED |
| Above a configurable amount threshold, MANAGER only (or dual approval) | PLANNED |
| Claim must be in `Review`; any other stage gets 409 | IMPLEMENTED in the state machine |
| AI/OCR output can never set a decision directly | PLANNED (AI_SECURITY.md) |

## Decision record (to implement)

A decision must be reconstructable later. Add a `claim_decisions` table (insert-only, same trigger pattern as `audit_events`):

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

1. Add `POST /claims/:claimId/decision` with `requireRole('ASSESSOR','MANAGER')`, `loadAuthorizedClaim(...,'read')` plus an org check, and a strict schema `{decision, amountCents, reasonCode, note}`.
2. In one D1 batch: insert into `claim_decisions`, set `claims.status`, and call `transitionClaim(c, claim, 'Decision')`.
3. Write the `claim.decision_recorded` audit event (IDs, amount and reason code only).
4. Add tests:
   - a customer deciding gets 403
   - deciding outside Review gets 409
   - a body containing `approvedBy` gets 400
   - a double decision gets 409
   - the record contains the evidence hashes
