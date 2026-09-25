# EasyClaim Backend: Repository Inventory

Verified by reading the source on branch `cyber`. The baseline is commit `efb6cc3` on `main`.
Status words used: IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / TESTED/PASSED / NOT TESTED / PLANNED.


## 1. Stack and structure

| Area | Finding | Evidence |
|---|---|---|
| Language | TypeScript 7.0.2 | `backend/package.json`, `backend/tsconfig.json` |
| Framework | Hono 4.13.9 on Cloudflare Workers | `backend/src/index.ts` |
| Build/run | Wrangler 4.141 (`wrangler dev`); no separate build step | `backend/wrangler.toml`, `backend/package.json` scripts |
| Entry point | `backend/src/index.ts`: default export `{ fetch, queue }` | `backend/src/index.ts` |
| Routes | 6 routers mounted under `/api/v1`: `client`, `covers`, `claims`, `ocr`, `profile`, `activities` | `backend/src/endpoints/*.ts` |
| Services layer | None. Logic lives in route handlers | — |
| Models / data access | `PolicyModel.getMyCovers` (parameterised SQL). Claims SQL is inline in `claims.ts` / `security/claimAccess.ts` | `backend/src/models/policyModel.ts` |
| Database | Cloudflare D1 binding `DB` (`easy-claim-db`) | `backend/wrangler.toml` |
| Migrations | Before: ad-hoc `schema.sql`. After: `backend/migrations/0001_init.sql`, `0002_security.sql` | `backend/migrations/` |
| Seed data | `backend/seed_sa_data.sql` (users `user123`, `user456`, `user789`) | — |
| Queue | Cloudflare Queue `claim-events` (producer `CLAIM_EVENTS` and consumer in the same Worker) | `backend/wrangler.toml`, `backend/src/endpoints/ocr.ts` |
| Frontend | `frontend/` has only a zustand store and TS types. **No UI** | `frontend/src/store/useAppStore.ts`, `frontend/src/types/index.ts` |
| Docker / deploy | No Dockerfile or CI. Deploy would be `wrangler deploy` (not performed) | — |

## 2. Capabilities: before vs after the cyber branch

| Capability | Before (`efb6cc3`) | After (`cyber`) | Evidence |
|---|---|---|---|
| Authentication | NOT IMPLEMENTED | NOT IMPLEMENTED. It fails closed (401). A **dev-only** header stub (`ALLOW_DEV_ACTOR_HEADERS`) exists for testing. Real auth is owned by the backend team | `src/security/actor.ts` |
| Authorization (RBAC) | NOT IMPLEMENTED | IMPLEMENTED (`requireRole`) for customer-only and insurer-only routes | `src/security/rbac.ts` |
| Object-level authz (claims) | NOT IMPLEMENTED (and `my-covers` hard-coded to `user123`) | IMPLEMENTED for every `:claimId` route. `my-covers` is scoped to the actor | `src/security/claimAccess.ts`, `src/endpoints/policy.ts` |
| Input validation | NOT IMPLEMENTED (`join-request` echoed the raw body) | IMPLEMENTED: strict zod schemas on all body/param inputs | `src/security/validation.ts` |
| Claim persistence | NOT IMPLEMENTED (all claim routes were stubs) | PARTIAL: initiate, screening and submit write to D1; timeline and decision read D1 | `src/endpoints/claims.ts` |
| Claim state machine | NOT IMPLEMENTED | IMPLEMENTED (pure transition table + conditional UPDATE). Only customer transitions are reachable via the API | `src/security/claimStateMachine.ts` |
| Evidence upload/storage | NOT IMPLEMENTED (endpoint only queued an event) | NOT IMPLEMENTED (same, now access-controlled). An `evidence` table exists but is unused | `src/endpoints/claims.ts`, `migrations/0002_security.sql` |
| OCR / AI | NOT IMPLEMENTED (stub) | NOT IMPLEMENTED (stub, insurer-only; queue messages schema-validated) | `src/endpoints/ocr.ts` |
| Screening / fraud logic | NOT IMPLEMENTED | NOT IMPLEMENTED (screening = customer narrative only) | — |
| Decisions | NOT IMPLEMENTED (`decision` returned `pending`) | PARTIAL: read-only from D1. No insurer decision endpoint | `src/endpoints/claims.ts` |
| Payout | NOT IMPLEMENTED | NOT IMPLEMENTED (state machine reserves Decision→Paid for MANAGER) | — |
| Notifications | Hard-coded demo data | Unchanged (hard-coded) | `src/endpoints/gateway.ts` |
| Audit logging | NOT IMPLEMENTED (console logs only) | IMPLEMENTED: append-only `audit_events` table with DB triggers blocking UPDATE/DELETE | `src/security/audit.ts`, `migrations/0002_security.sql` |
| Rate limiting | NOT IMPLEMENTED | IMPLEMENTED: Workers Rate Limiting binding, 100 req / 60 s per IP on `/api/*` | `src/index.ts`, `wrangler.toml` |
| Security headers / CORS | NOT IMPLEMENTED | IMPLEMENTED: `secureHeaders`, CORS allowlist from `ALLOWED_ORIGINS` | `src/index.ts` |
| Error handling | Hono defaults | IMPLEMENTED: JSON 404, generic 500 with no stack or internals | `src/index.ts` |
| Body size limit | NOT IMPLEMENTED | IMPLEMENTED: 64 KB | `src/index.ts` |
| Tests | NOT IMPLEMENTED (`npm test` exited 1) | 9 files, 85 tests, TESTED/PASSED | `backend/test/` |
| Dependency scan | — | `npm audit`: 0 vulnerabilities | — |
| Secrets in repo | None found | None. `.dev.vars` gitignored; `.dev.vars.example` committed | `backend/.gitignore` |

## 3. Configuration and environment variables

| Name | Where | Required | Purpose |
|---|---|---|---|
| `DB` | `wrangler.toml` D1 binding | Yes | Database |
| `CLAIM_EVENTS` | `wrangler.toml` queue producer | Yes (code tolerates absence) | Claim events |
| `RATE_LIMITER` | `wrangler.toml` `[[ratelimits]]` | Recommended (middleware skips if absent) | Throttling |
| `ALLOWED_ORIGINS` | `wrangler.toml` `[vars]` (default empty), `.dev.vars` | Optional | CORS allowlist, comma-separated |
| `ALLOW_DEV_ACTOR_HEADERS` | `.dev.vars` **only** | Local dev/testing only | Enables the spoofable `X-Dev-Actor-*` stub. Must never be set in a deployed environment |

The `database_id` in `wrangler.toml` is a resource identifier, not a secret.

## 4. Endpoint inventory (24 routes)

Legend: "Actor" means an actor is resolved by `requireActor`. All `/api/v1/*` routes return 401 without one.

| # | Method | Path | Purpose | Auth before → after | Role (after) | Object accessed | Request fields | Response fields | Side effects | Sensitive data | Security concerns / notes | Tests |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | GET | `/api/v1/client/home` | Dashboard banner | none → actor | any | none | — | `message`, `alerts[]` | none | none (hard-coded) | Same demo data for every user | `actor.test.ts` |
| 2 | GET | `/api/v1/client/services/most-visited` | Shortcuts | none → actor | any | none | — | `data[]` | none | none | Hard-coded | NOT TESTED directly |
| 3 | GET | `/api/v1/client/notifications` | Notifications | none → actor | any | none | — | `notifications[]` | none | none | Hard-coded; not user-scoped | NOT TESTED directly |
| 4 | GET | `/api/v1/client/activity/recent` | Recent activity | none → actor | any | none | — | `activity[]` | none | none | Hard-coded; not user-scoped | NOT TESTED directly |
| 5 | GET | `/api/v1/covers/my-covers` | Caller's policies | none (hard-coded `user123`) → actor | CUSTOMER | `policies` by `user_id` | — | `policies[]` | none | Plan names, policy IDs | Now scoped to `actor.id` | `bola.test.ts`, `rbac.test.ts`, `hardening.test.ts` |
| 6 | GET | `/api/v1/covers/market-catalog` | Product catalog | none → actor | any | static list | — | `catalog[]` | none | none | Public-style data behind auth | `actor.test.ts`, `hardening.test.ts` |
| 7 | POST | `/api/v1/covers/join-request` | Request to join a plan | none → actor | CUSTOMER | catalog plan | `planId` (strict) | `status`, `message`, `planId`, `provider` | audit `cover.join_requested` | none | Before: echoed the raw body and accepted `userId`. Now strict, no echo | `massAssignment.test.ts`, `hardening.test.ts` |
| 8 | GET | `/api/v1/claims/status` | Service status | none → actor | any | none | — | `status` | none | none | — | `actor.test.ts` |
| 9 | POST | `/api/v1/claims/verify-eligibility` | Wizard step 2 | none (always `verified:true`) → actor | CUSTOMER | policy (owned) | `policyId` | `verified`, `context{isIdentityValid:null, isPolicyActive, waitingPeriodCleared:null}` | none | none | Identity and waiting-period checks NOT IMPLEMENTED (reported `null`) | `bola.test.ts` |
| 10 | POST | `/api/v1/claims/initiate` | Create draft claim | none (fake `claim_${Date.now()}`) → actor | CUSTOMER | policy (must be owned + Active) | `policyId`, `category?` | `status`, `claimId` (`claim_<uuid>`) | INSERT claim `Draft`; audit `claim.created` / `claim.initiate_rejected` | claim ID | Enumerable IDs replaced by UUIDs | `claimLifecycle.test.ts`, `massAssignment.test.ts`, `bola.test.ts` |
| 11 | PATCH | `/api/v1/claims/:claimId/screening` | Wizard step 3 | none (no-op) → actor | CUSTOMER (owner) | claim | `causeOfLoss` (≤2000), `incidentDate` (ISO, not future) | `status`, `message` | UPDATE claim; audit; Info Needed→Screening transition | narrative text (not logged to audit) | Editable only in `Draft`/`Info Needed` | `massAssignment.test.ts`, `bola.test.ts`, `claimLifecycle.test.ts` |
| 12 | POST | `/api/v1/claims/:claimId/evidence-ocr` | Wizard step 4 | none → actor | CUSTOMER (owner) | claim | — (no file accepted) | `status`, `message` (202) | queue `ClaimEvidenceUploaded`; audit `claim.evidence_queued` | none | **No upload/storage exists** | `bola.test.ts` |
| 13 | POST | `/api/v1/claims/:claimId/submit` | Wizard step 5 | none → actor | CUSTOMER (owner) | claim | — | `status`, `message`, `claimId` | Draft→Submitted (conditional UPDATE); queue `ClaimSubmitted`; audit | none | Requires completed screening; replay gives 409 | `claimLifecycle.test.ts`, `bola.test.ts` |
| 14 | GET | `/api/v1/claims/:claimId/timeline` | Tracking | none (fake data) → actor | owner CUSTOMER, ASSESSOR, MANAGER | claim + its audit rows | — | `claimId`, `currentStage`, `timeline[]` | none | claim stage | Insurer read has no tenant scoping (see gaps) | `bola.test.ts`, `claimLifecycle.test.ts` |
| 15 | GET | `/api/v1/claims/:claimId/decision` | Decision status | none → actor | owner CUSTOMER, ASSESSOR, MANAGER | claim | — | `decision` | none | decision outcome | Read-only | `bola.test.ts` |
| 16 | POST | `/api/v1/claims/:claimId/appeal` | Appeal a rejection | none → actor | CUSTOMER (owner) | claim | `reason` (≤2000) | `status` | Decision→Appeal; audit | none | Only when `stage=Decision` and `status=Rejected` | `claimLifecycle.test.ts`, `bola.test.ts` |
| 17 | POST | `/api/v1/ocr/process` | OCR stub | none → actor | ASSESSOR, MANAGER | none | — | `extracted` | none | none | Stub; no OCR engine | `rbac.test.ts` |
| 18 | GET | `/api/v1/profile` | Profile | none → actor | any | none | — | `profile{}` | none | none | Stub (empty) | `actor.test.ts` |
| 19 | PATCH | `/api/v1/profile` | Update profile | none → actor | any | none | ignored | `updated:true` | **none** (no-op) | — | Stub returns success without doing anything | NOT TESTED |
| 20 | GET | `/api/v1/profile/consent` | Consent state | none → actor | any | none | — | `consent:true` | none | — | Hard-coded `true`; POPIA consent NOT IMPLEMENTED | NOT TESTED |
| 21 | GET | `/api/v1/profile/mandates/:tenantId/check` | Debit mandate check | none → actor | any | `tenantId` (unchecked) | — | `active:true` | none | — | **No object check** on `tenantId` (stub) | NOT TESTED |
| 22 | POST | `/api/v1/profile/mandates/cancel` | Cancel mandate | none → actor | CUSTOMER | none | ignored | `cancelled:true` | audit `mandate.cancel_requested` | — | Stub; no step-up auth | `rbac.test.ts` |
| 23 | GET | `/api/v1/activities/history` | History | none → actor | any | none | — | `history[]` (empty) | none | — | Stub | `actor.test.ts` |
| 24 | GET | `/api/v1/activities/audit-trail` | Audit trail | none → actor | any | none | — | `trail[]` (empty) | none | — | Stub. Does **not** read `audit_events`. If wired up, restrict it to insurer/admin roles | `actor.test.ts` |

Queue consumer (`queue()` in `src/index.ts` → `processQueueBatch` in `src/endpoints/ocr.ts`): validates message shape and acks malformed messages. It now handles `ClaimEvidenceUploaded`, which was previously silently dropped. Tested in `test/queue.test.ts`. Under `wrangler dev` the local consumer did **not** fire, both before and after the changes, so it has not been verified live.

## 5. Existing security controls found at baseline (`efb6cc3`)

- Parameterised SQL in `PolicyModel.getMyCovers`. That was the only control.

## 6. Missing or uncertain controls (after cyber branch)

- Real authentication (tokens, sessions, IdP): NOT IMPLEMENTED. Owned by the backend team.
- Tenant/insurer scoping: ASSESSOR/MANAGER can read **any** claim. There is no organisation model.
- Insurer workflow endpoints (verify, screen, request info, decide, pay): NOT IMPLEMENTED.
- Evidence upload, storage, hashing, file validation: NOT IMPLEMENTED.
- OCR/AI: NOT IMPLEMENTED.
- Payout, step-up auth, configuration management/versioning: NOT IMPLEMENTED.
- Profile, consent, mandate endpoints are stubs. `mandates/:tenantId/check` has no object check.
- Rate limiting is per IP and approximate (by design of the binding). There are no per-user or per-operation limits.
- Queue consumer not verified under `wrangler dev`.

## 7. Verification evidence

- `npm run typecheck`: pass.
- `npm test`: 9 files, 85 tests, TESTED/PASSED.
- Mutation check: disabling the ownership check in `loadAuthorizedClaim` made 5 BOLA tests fail, as expected. Restored afterwards.
- `npm audit`: 0 vulnerabilities.
- Live `wrangler dev` checks: no actor → 401; IDOR → 404; customer → `/ocr/process` 403; mass assignment → 400; replay submit → 409; burst of 120 requests → 7 × 429.
