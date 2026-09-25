# API Security Matrix

Per-endpoint security state on branch `cyber`. Status words: IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / TESTED/PASSED / NOT TESTED / PLANNED.

**Global controls (all 24 routes):**

- Actor required (`requireActor`, 401 otherwise). **Authentication itself is NOT IMPLEMENTED**: the actor comes from a dev-only header stub.
- Rate limit of 100 req / 60 s per IP (TESTED/PASSED in `hardening.test.ts`; 429 observed live).
- 64 KB body limit.
- Security headers and CORS allowlist.
- Generic 500 errors.

**Object-level question** asked for each ID parameter: *"Does the server verify that this actor is allowed to access this specific object?"*

| Method | Path | Auth | Role | Object-level check | Property-level protection | Audit event | Tests | Remaining gaps |
|---|---|---|---|---|---|---|---|---|
| GET | `/client/home` | actor | any | n/a (no ID) | n/a | none | `actor.test.ts` TESTED/PASSED (401) | Hard-coded demo data, identical for all users |
| GET | `/client/services/most-visited` | actor | any | n/a | n/a | none | NOT TESTED | Demo data |
| GET | `/client/notifications` | actor | any | n/a | n/a | none | NOT TESTED | Demo data, not user-scoped |
| GET | `/client/activity/recent` | actor | any | n/a | n/a | none | NOT TESTED | Demo data, not user-scoped |
| GET | `/covers/my-covers` | actor | CUSTOMER | **Yes**: query filtered by `actor.id` (was hard-coded `user123`) | n/a | none | `bola.test.ts`, `rbac.test.ts` TESTED/PASSED | Returns raw DB rows (`user_id` included) |
| GET | `/covers/market-catalog` | actor | any | n/a | n/a | none | `hardening.test.ts` TESTED/PASSED | — |
| POST | `/covers/join-request` | actor | CUSTOMER | `planId`: validated against the server catalog; not user-owned data | Strict schema `{planId}`; `userId` rejected; body no longer echoed; `provider` from catalog | `cover.join_requested` | `massAssignment.test.ts` TESTED/PASSED | No persistence; no duplicate-request protection |
| GET | `/claims/status` | actor | any | n/a | n/a | none | `actor.test.ts` TESTED/PASSED | — |
| POST | `/claims/verify-eligibility` | actor | CUSTOMER | `policyId`: **Yes**, looked up with `user_id = actor.id`; another user's policy returns `verified:false` | Strict schema | none | `bola.test.ts` TESTED/PASSED | Identity and waiting-period checks NOT IMPLEMENTED (return `null`) |
| POST | `/claims/initiate` | actor | CUSTOMER | `policyId`: **Yes**, must be owned and `Active`, else 422 | Strict schema; `stage`/`userId` rejected; stage=`Draft`, status=`Pending`, owner=`actor.id` set by server; UUID claim IDs | `claim.created` / `claim.initiate_rejected` | `claimLifecycle.test.ts`, `massAssignment.test.ts`, `bola.test.ts` TESTED/PASSED | No limit on drafts per user |
| PATCH | `/claims/:claimId/screening` | actor | CUSTOMER | `claimId`: **Yes**, `loadAuthorizedClaim(owner-write)`, 404 if not owner | Strict `{causeOfLoss, incidentDate}`; `stage`, `status`, `riskScore`, `decision`, `approvedBy`, `user_id` rejected; editable only in Draft / Info Needed | `claim.screening_updated`, `claim.stage_changed` (Info Needed→Screening) | `massAssignment.test.ts`, `bola.test.ts`, `claimLifecycle.test.ts` TESTED/PASSED | — |
| POST | `/claims/:claimId/evidence-ocr` | actor | CUSTOMER | `claimId`: **Yes** (owner-write) | No body accepted | `claim.evidence_queued` | `bola.test.ts` TESTED/PASSED | **No file upload/storage**: evidence controls are NOT IMPLEMENTED; no per-claim throttle on queued events |
| POST | `/claims/:claimId/submit` | actor | CUSTOMER | `claimId`: **Yes** (owner-write) | Stage change only via state machine; conditional UPDATE blocks replay (409) | `claim.stage_changed` / `claim.transition_rejected` | `claimLifecycle.test.ts`, `bola.test.ts` TESTED/PASSED | — |
| GET | `/claims/:claimId/timeline` | actor | owner, ASSESSOR, MANAGER | `claimId`: **Yes** for customers. **PARTIAL** for insurer roles: any ASSESSOR/MANAGER can read any claim (no tenant model) | n/a | denial → `authz.claim_access_denied` | `bola.test.ts`, `claimLifecycle.test.ts` TESTED/PASSED | Needs insurer/tenant scoping |
| GET | `/claims/:claimId/decision` | actor | owner, ASSESSOR, MANAGER | `claimId`: same as timeline | n/a | denial audited | `bola.test.ts` TESTED/PASSED | Same tenant gap |
| POST | `/claims/:claimId/appeal` | actor | CUSTOMER | `claimId`: **Yes** (owner-write) | Strict `{reason}`; allowed only when stage=`Decision` and status=`Rejected` | `claim.stage_changed` | `claimLifecycle.test.ts`, `bola.test.ts` TESTED/PASSED | `reason` not persisted |
| POST | `/ocr/process` | actor | ASSESSOR, MANAGER | n/a (stub) | n/a | denial → `authz.role_denied` | `rbac.test.ts` TESTED/PASSED | Stub |
| GET | `/profile` | actor | any | n/a | n/a | none | `actor.test.ts` TESTED/PASSED (401) | Stub returns `{}` |
| PATCH | `/profile` | actor | any | n/a | **None**: body ignored, returns `updated:true` | none | NOT TESTED | Stub reports success without doing anything |
| GET | `/profile/consent` | actor | any | n/a | n/a | none | NOT TESTED | Hard-coded `consent:true`; POPIA consent tracking NOT IMPLEMENTED |
| GET | `/profile/mandates/:tenantId/check` | actor | any | `tenantId`: **No**, not validated or checked against the actor (stub) | n/a | none | NOT TESTED | Must add object check + validation when implemented |
| POST | `/profile/mandates/cancel` | actor | CUSTOMER | n/a (stub; no mandate ID) | Body ignored | `mandate.cancel_requested` | `rbac.test.ts` TESTED/PASSED (insurer 403) | No step-up auth; stub |
| GET | `/activities/history` | actor | any | n/a | n/a | none | `actor.test.ts` TESTED/PASSED (401) | Stub (empty) |
| GET | `/activities/audit-trail` | actor | any | n/a | n/a | none | `actor.test.ts` TESTED/PASSED (401) | Stub (empty). If wired to `audit_events`, must be restricted to insurer/admin roles and scoped |

**Queue consumer** (`processQueueBatch`):

- Messages are validated with zod; malformed or injected payloads are acked and discarded rather than retried forever. TESTED/PASSED in `queue.test.ts`.
- Not verified live under `wrangler dev`.

## Summary of ID parameters

| Parameter | Routes | Object check | Status |
|---|---|---|---|
| `claimId` | screening, evidence-ocr, submit, timeline, decision, appeal | `loadAuthorizedClaim` | IMPLEMENTED, TESTED/PASSED (insurer tenant scoping NOT IMPLEMENTED) |
| `policyId` | verify-eligibility, initiate | `user_id = actor.id` | IMPLEMENTED, TESTED/PASSED |
| `planId` | join-request | server catalog lookup | IMPLEMENTED, TESTED/PASSED |
| `tenantId` | mandates/:tenantId/check | none | NOT IMPLEMENTED |
