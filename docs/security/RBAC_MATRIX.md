# RBAC Matrix

## What exists in code

- The roles `CUSTOMER`, `ASSESSOR`, `MANAGER`, `ADMIN` exist **only** as the `Role` type in `backend/src/types.ts` (`INSURER_ROLES = ['ASSESSOR','MANAGER']`).
- There is **no identity provider and no user or role store**. The actor comes from `resolveActor` in `backend/src/security/actor.ts`. That function fails closed with 401, except that when the local-only flag `ALLOW_DEV_ACTOR_HEADERS=true` is set, it trusts the `X-Dev-Actor-Id` / `X-Dev-Actor-Role` headers. This is a dev stub and **NOT authentication**.
- Enforcement lives in three places:
  - `requireActor` (`src/index.ts` on `/api/v1/*`)
  - `requireRole(...)` (`src/security/rbac.ts`)
  - `loadAuthorizedClaim(c, id, 'read' | 'owner-write')` (`src/security/claimAccess.ts`)
  - Stage changes additionally go through `checkTransition` (`src/security/claimStateMachine.ts`).
- **Tenant/org scoping is NOT IMPLEMENTED.** There is no organisation model, so ASSESSOR/MANAGER can read **all** claims, including those of other insurers.
- **ADMIN has no claim powers** by design (separation of duties). ADMIN-only functions (config, roles) don't exist yet.

## Matrix

"Enforced" means the rule is in code and tested today. "Planned" means the rule is defined here but has no endpoint yet.

| Action | Endpoint | Allowed role | Ownership | Tenant/org | Step-up | Audit event | Status / enforcement |
|---|---|---|---|---|---|---|---|
| List own covers | `GET /covers/my-covers` | CUSTOMER | Actor's policies only | n/a | No | No (read) | Enforced: `policy.ts` `requireRole('CUSTOMER')`, query by `actor.id` |
| View catalog | `GET /covers/market-catalog` | Any authenticated | — | — | No | No | Enforced (auth only) |
| Join request | `POST /covers/join-request` | CUSTOMER | Actor is the requester (client `userId` rejected) | n/a | No | `cover.join_requested` | Enforced |
| Check eligibility | `POST /claims/verify-eligibility` | CUSTOMER | Policy must belong to the actor | n/a | No | No | Enforced |
| Start claim | `POST /claims/initiate` | CUSTOMER | Policy must belong to the actor and be Active | n/a | No | `claim.created` / `claim.initiate_rejected` | Enforced |
| Edit screening answers | `PATCH /claims/:id/screening` | CUSTOMER | Owner (`owner-write`); stage Draft or Info Needed | n/a | No | `claim.screening_updated` | Enforced |
| Add evidence (queue only) | `POST /claims/:id/evidence-ocr` | CUSTOMER | Owner; stage Draft or Info Needed | n/a | No | `claim.evidence_queued` | Enforced (no file handling exists) |
| Submit claim | `POST /claims/:id/submit` | CUSTOMER | Owner; Draft → Submitted | n/a | No | `claim.stage_changed` | Enforced |
| View timeline / decision | `GET /claims/:id/timeline`, `/decision` | CUSTOMER (owner), ASSESSOR, MANAGER | Owner, or insurer staff | **Required, NOT IMPLEMENTED** | No | Denials audited (`authz.claim_access_denied`) | Enforced for owner/role; tenant missing |
| Appeal | `POST /claims/:id/appeal` | CUSTOMER | Owner; stage Decision and status Rejected | n/a | No | `claim.stage_changed` | Enforced |
| Run OCR (stub) | `POST /ocr/process` | ASSESSOR, MANAGER | — | Required, NOT IMPLEMENTED | No | Denials audited (`authz.role_denied`) | Enforced (role) |
| Cancel debit mandate (stub) | `POST /profile/mandates/cancel` | CUSTOMER | Own mandate (**not checked**: stub has no mandate data) | n/a | **Yes (planned)** | `mandate.cancel_requested` | Partial |
| Check mandate (stub) | `GET /profile/mandates/:tenantId/check` | Any authenticated | Should be own mandate | — | No | No | NOT IMPLEMENTED (stub) |
| Verify claim | *(none)* | ASSESSOR, MANAGER | — | Required | No | `claim.stage_changed` | Planned (transition rule Submitted→Verified exists) |
| Screen / move to review | *(none)* | ASSESSOR, MANAGER | — | Required | No | `claim.stage_changed` | Planned |
| Request more info | *(none)* | ASSESSOR, MANAGER | — | Required | No | `claim.stage_changed` + reason | Planned |
| Decide (approve/reject) | *(none)* | ASSESSOR, MANAGER (high value: MANAGER) | Decider ≠ claimant | Required | Recommended for high value | `claim.decision_recorded` (see DECISION_SECURITY.md) | Planned (Review→Decision rule exists) |
| Pay out | *(none)* | MANAGER only | Decider should differ from payer (dual control) | Required | **Yes** | `claim.payout_*` | Planned (Decision→Paid is MANAGER-only in the table) |
| Review appeal | *(none)* | MANAGER | Must not be the original decider | Required | No | `claim.stage_changed` | Planned (Appeal→Review rule exists) |
| Expire stale info request | *(scheduled job)* | SYSTEM | — | — | n/a | `claim.stage_changed` | Planned |
| Delete or replace evidence | *(none)* | CUSTOMER before submit; nobody after (supersede instead) | Owner | — | No | `evidence.deleted` / `evidence.superseded` | Planned |
| Change config (fraud thresholds, limits) | *(none)* | ADMIN | — | Org-scoped | **Yes** | `config.changed` (old, new, version, reason) | Planned |
| Change user role | *(none)* | ADMIN | Cannot change own role | Org-scoped | **Yes** | `role.changed` | Planned |

Tests: `backend/test/rbac.test.ts`, `backend/test/bola.test.ts`, `backend/test/stateMachine.test.ts`.
