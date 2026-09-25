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

## Design decisions

- **`Draft` was added**, because `POST /claims/initiate` already created a draft before submission. Draft claims are editable; Submitted claims are not.
- **Title-case stage strings** (`'Info Needed'`, `'Review'`) are used instead of SUBMITTED/VERIFIED because `seed_sa_data.sql` and `frontend/src/types/index.ts` (`ClaimSummary.stage`) already use them, so no data migration is needed.
- **ADMIN has no transitions**, for separation of duties.
- **Paid is MANAGER-only.** `SYSTEM` is used only for scheduled expiry and can never be a request actor, because `resolveActor` only accepts the four real roles.
- **`status`** (Pending/Approved/Rejected) is the decision outcome, is server-set, and can't be written by clients (strict schemas).

## Replay and race protection

`transitionClaim` (`backend/src/security/claimAccess.ts`) runs:

```sql
UPDATE claims SET stage = ?, updated_at = ? WHERE id = ? AND stage = ?
```

The final `stage = ?` is the stage the caller read. If another request already moved the claim, `meta.changes` is 0 and the API returns 409 `stale_state`. A replayed or duplicate submit gets 409; this was verified live.

## Reachability today

| Transition | Reachable via API? | Where |
|---|---|---|
| Draft → Submitted | Yes | `POST /claims/:id/submit` (requires screening answers first, else 422) |
| Info Needed → Screening | Yes | `PATCH /claims/:id/screening` when stage is Info Needed |
| Decision → Appeal | Yes | `POST /claims/:id/appeal` (only when status = Rejected) |
| Every insurer transition, Paid, Withdrawn, Expired | **No endpoint exists** | Enforced only by the pure function `checkTransition`. Backend team must route any new endpoint through `transitionClaim` (BACKEND-SEC-003) |

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
