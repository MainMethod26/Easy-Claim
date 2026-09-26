# EasyClaim Backend: Repository Inventory

Verified by reading the source on branch `cyber`. The baseline is commit `efb6cc3` on `main`.
Status words used: IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / TESTED/PASSED / NOT TESTED / PLANNED / BLOCKED / DECISION REQUIRED.

**Phase 1 update (branch `cyber`: commit `cb2588a` on top of the Phase 0 commit `1468897`; every statement below was re-verified against the working tree on 2026-09-26):** bearer JWT authentication, an insurer tenant model, `GET /claims` and six insurer transition endpoints were added. The Phase 0 findings below are kept as written; each superseded statement carries a short "Phase 1 update" note pointing at the section that replaces it, and the new material is in sections 2a, 3, 4a, 6 and 7.


## 1. Stack and structure

| Area | Finding | Evidence |
|---|---|---|
| Language | TypeScript 7.0.2 | `package.json`, `tsconfig.json` |
| Framework | Hono 4.13.9 on Cloudflare Workers | `src/index.ts` |
| Build/run | Wrangler 4.141 (`wrangler dev`); no separate build step | `wrangler.toml`, `package.json` scripts |
| Entry point | `src/index.ts`: default export `{ fetch, queue }` | `src/index.ts` |
| Routes | 6 routers mounted under `/api/v1`: `client`, `covers`, `claims`, `ocr`, `profile`, `activities`. Phase 1 update: 7 routers; `claimsInsurer.ts` is mounted under `/api/v1/claims` as well (31 routes, see section 4) | `src/endpoints/*.ts`, `src/index.ts` |
| Services layer | None. Logic lives in route handlers | — |
| Models / data access | `PolicyModel.getMyCovers` (parameterised SQL). Claims SQL is inline in `claims.ts` / `security/claimAccess.ts` | `src/models/policyModel.ts` |
| Database | Cloudflare D1 binding `DB` (`easy-claim-db`) | `wrangler.toml` |
| Migrations | Before: ad-hoc `schema.sql`. After: `migrations/0001_init.sql`, `0002_security.sql`. Phase 1 update: `0003_tenants.sql` (tenants table, `tenant_id` on policies and claims, `audit_events.actor_tenant_id`, backfill of the five seed policies by id only, indexes) | `migrations/` |
| Seed data | `seed_sa_data.sql` (users `user123`, `user456`, `user789`). Phase 1 update: policies and claims are seeded with `tenant_id`; the five tenants (`ins_discovery`, `ins_sanlam`, `ins_outsurance`, `ins_momentum`, `ins_oldmutual`) are inserted by migration 0003 | — |
| Local scripts (Phase 1) | `scripts/setup-dev-vars.mjs` (`npm run setup:local`: creates `.dev.vars` with a random `JWT_SECRET`, never overwrites an existing file) and `scripts/mint-token.mjs` (`npm run token -- --demo \| --postman \| --sub X --role Y [--tenant Z]`: local HS256 tokens, `iat` backdated 60 s, refuses claims the server would reject). `npm run secret` prints a random 32-byte secret | `scripts/`, `package.json` |
| Queue | Cloudflare Queue `claim-events` (producer `CLAIM_EVENTS` and consumer in the same Worker) | `wrangler.toml`, `src/endpoints/ocr.ts` |
| Frontend | `frontend/` has only a zustand store and TS types. **No UI** | `frontend/src/store/useAppStore.ts`, `frontend/src/types/index.ts` |
| Docker / deploy | No Dockerfile or CI. Deploy would be `wrangler deploy` (not performed) | — |

## 2. Capabilities: before vs after the cyber branch

Phase 0 table, unchanged. Where Phase 1 changed a row, section 2a below supersedes it.

| Capability | Before (`efb6cc3`) | After Phase 0 (`cyber` at `1468897`) | Evidence |
|---|---|---|---|
| Authentication | NOT IMPLEMENTED | NOT IMPLEMENTED. It fails closed (401). A **dev-only** header stub (`ALLOW_DEV_ACTOR_HEADERS`) exists for testing. Real auth is owned by the backend team. **Phase 1 update: the `X-Dev-Actor-*` stub and `ALLOW_DEV_ACTOR_HEADERS` are REMOVED; bearer JWT authentication is IMPLEMENTED (section 2a)** | `src/security/actor.ts` |
| Authorization (RBAC) | NOT IMPLEMENTED | IMPLEMENTED (`requireRole`) for customer-only and insurer-only routes. Phase 1 update: see 2a (ADMIN denied on `GET /claims`) | `src/security/rbac.ts` |
| Object-level authz (claims) | NOT IMPLEMENTED (and `my-covers` hard-coded to `user123`) | IMPLEMENTED for every `:claimId` route. `my-covers` is scoped to the actor. Phase 1 update: tenant boundary added, see 2a | `src/security/claimAccess.ts`, `src/endpoints/policy.ts` |
| Input validation | NOT IMPLEMENTED (`join-request` echoed the raw body) | IMPLEMENTED: strict zod schemas on all body/param inputs. Phase 1 update: `decideSchema` (strict body) and `listQuerySchema` (`GET /claims` query; validates `limit` only, other query parameters are ignored) added | `src/security/validation.ts` |
| Claim persistence | NOT IMPLEMENTED (all claim routes were stubs) | PARTIAL: initiate, screening and submit write to D1; timeline and decision read D1. Phase 1 update: see 2a | `src/endpoints/claims.ts` |
| Claim state machine | NOT IMPLEMENTED | IMPLEMENTED (pure transition table + conditional UPDATE). Only customer transitions are reachable via the API. Phase 1 update: insurer transitions reachable, see 2a | `src/security/claimStateMachine.ts` |
| Evidence upload/storage | NOT IMPLEMENTED (endpoint only queued an event) | NOT IMPLEMENTED (same, now access-controlled). An `evidence` table exists but is unused | `src/endpoints/claims.ts`, `migrations/0002_security.sql` |
| OCR / AI | NOT IMPLEMENTED (stub) | NOT IMPLEMENTED (stub, insurer-only; queue messages schema-validated) | `src/endpoints/ocr.ts` |
| Screening / fraud logic | NOT IMPLEMENTED | NOT IMPLEMENTED (screening = customer narrative only) | — |
| Decisions | NOT IMPLEMENTED (`decision` returned `pending`) | PARTIAL: read-only from D1. No insurer decision endpoint. Phase 1 update: `POST /claims/:claimId/decide` added, see 2a | `src/endpoints/claims.ts` |
| Payout | NOT IMPLEMENTED | NOT IMPLEMENTED (state machine reserves Decision→Paid for MANAGER). Phase 1 update: PARTIAL, state transition only, see 2a | — |
| Notifications | Hard-coded demo data | Unchanged (hard-coded) | `src/endpoints/gateway.ts` |
| Audit logging | NOT IMPLEMENTED (console logs only) | IMPLEMENTED: append-only `audit_events` table with DB triggers blocking UPDATE/DELETE | `src/security/audit.ts`, `migrations/0002_security.sql` |
| Rate limiting | NOT IMPLEMENTED | IMPLEMENTED: Workers Rate Limiting binding, 100 req / 60 s per IP on `/api/*`. Phase 1 update: per-actor limit added, see 2a | `src/index.ts`, `wrangler.toml` |
| Security headers / CORS | NOT IMPLEMENTED | IMPLEMENTED: `secureHeaders`, CORS allowlist from `ALLOWED_ORIGINS`. Phase 1 update: see 2a | `src/index.ts` |
| Error handling | Hono defaults | IMPLEMENTED: JSON 404, generic 500 with no stack or internals | `src/index.ts` |
| Body size limit | NOT IMPLEMENTED | IMPLEMENTED: 64 KB | `src/index.ts` |
| Tests | NOT IMPLEMENTED (`npm test` exited 1) | 9 files, 85 tests, TESTED/PASSED. Phase 1 update: 12 files, 183 passed + 1 todo, see 2a. Phase 5 update: 17 files, 264 passed | `test/` |
| Dependency scan | — | `npm audit`: 0 vulnerabilities (re-run in Phase 1: still 0) | — |
| Secrets in repo | None found | None. `.dev.vars` gitignored; `.dev.vars.example` committed. Phase 1 update: see 2a (`JWT_SECRET`, Postman environment) | `.gitignore` |

### 2a. Phase 1 update (supersedes the rows of the same name above)

| Capability | Phase 0 (`cyber` at `1468897`) | Phase 1 (`cb2588a` / working tree) | Evidence |
|---|---|---|---|
| Authentication | NOT IMPLEMENTED (dev header stub) | IMPLEMENTED: `Authorization: Bearer <JWT>`, verified with `hono/jwt` `verify(token, JWT_SECRET, { alg: 'HS256', iss: JWT_ISSUER, aud: JWT_AUDIENCE })`. `validateClaims()`: `exp` and `iat` required, `exp <= now` rejected, remaining lifetime capped by `MAX_TOKEN_TTL_SECONDS` (CUSTOMER 24 h; ASSESSOR/MANAGER/ADMIN 8 h), `sub` and `tenant_id` must match `ID_PATTERN`, `role` in `ROLES`, `tenant_id` required for ASSESSOR/MANAGER, forbidden for CUSTOMER, optional for ADMIN (DECISION REQUIRED). Missing `JWT_SECRET` (< 32 bytes), `JWT_ISSUER` or `JWT_AUDIENCE` → every request 401 (fail closed, logged as misconfigured). 401 body is exactly `{"error":"unauthenticated"}` with `WWW-Authenticate: Bearer`; logs carry only the hono error class name or a fixed reason token, never the token; no audit row for unauthenticated requests. The `X-Dev-Actor-*` stub and `ALLOW_DEV_ACTOR_HEADERS` are removed. IdP/JWKS (`verifyWithJwks`) PLANNED; revocation PLANNED. TESTED/PASSED (`auth.test.ts` AUTH-001..014, `actor.test.ts`) | `src/security/actor.ts`, `src/types.ts` |
| Authorization (RBAC) | IMPLEMENTED (`requireRole`) | IMPLEMENTED: coarse `requireRole` per route (resource-independent, so it cannot act as a cross-tenant oracle), per-transition role inside the state machine, ADMIN denied on claim routes (`GET /claims` → 403 audited). TESTED/PASSED (RBAC-001/002) | `src/security/rbac.ts`, `src/endpoints/claimsInsurer.ts` |
| Object-level authz (claims) | IMPLEMENTED (ownership only; insurer read unscoped) | IMPLEMENTED with tenant scoping: `loadAuthorizedClaim(c, claimId, mode)` with modes `read` / `owner-write` / `insurer`; decision order load → tenant → ownership → mode; `isTenantInsurer()` = insurer role AND `actor.tenantId === claim.tenant_id` (non-null) AND `claim.stage !== 'Draft'`. Denial or missing → 404 `{"error":"not_found"}` + audit `authz.claim_access_denied` `{mode, exists, reason}` (reasons `missing`, `not_owner`, `cross_tenant`, `tenant_unset`, `draft`, `role`, `mode`, `transition_guard`). TESTED/PASSED (TENANT-001..007 except 004) | `src/security/claimAccess.ts` |
| Tenant model | NOT IMPLEMENTED | IMPLEMENTED: `tenants` table; `policies.tenant_id` and `claims.tenant_id` `REFERENCES tenants`; `audit_events.actor_tenant_id`; `POST /claims/initiate` copies `tenant_id` from the policy (policy without tenant → 422 `policy_not_eligible`, audited reason `policy_missing_tenant`); a claim with NULL tenant is visible to no insurer. Actor is `{ id, role, tenantId: string \| null }`; customers are platform-level (no tenant), insurer staff belong to exactly one tenant. Tenant admin functions NOT IMPLEMENTED. TESTED/PASSED (`tenant.test.ts`, `migration.test.ts`) | `migrations/0003_tenants.sql`, `src/types.ts` |
| Claim persistence | PARTIAL | PARTIAL: as before plus `GET /claims` (list) and insurer stage changes; still no evidence, decision record or payment data | `src/endpoints/claims.ts`, `src/endpoints/claimsInsurer.ts` |
| Claim state machine | IMPLEMENTED (customer transitions only over HTTP) | IMPLEMENTED, transition table unchanged; all insurer transitions now reachable over HTTP. `transitionClaim(c, claim, to, opts)` re-asserts owner/tenant (403 + audit reason `transition_guard`), checks the edge and per-transition role (403 `forbidden` / 409 `illegal_transition`, audit `claim.transition_rejected`), then ONE D1 batch: `UPDATE ... WHERE id=? AND stage=?` plus audit `INSERT ... WHERE changes() = 1`; 0 rows → 409 `stale_state` (audited). Withdrawn and Expired still have no endpoint/job. TESTED/PASSED (STATE-001..006) | `src/security/claimStateMachine.ts`, `src/security/claimAccess.ts` |
| Decisions | PARTIAL (read-only) | PARTIAL: `POST /claims/:claimId/decide` `{ outcome: Approved \| Rejected }` (strict) writes `claims.status` in the same statement as the stage change. No amount, reason or decision record | `src/endpoints/claimsInsurer.ts`, `src/security/validation.ts` |
| Payout | NOT IMPLEMENTED | PARTIAL: `POST /claims/:claimId/pay` is a MANAGER-only (state machine) Decision → Paid transition that requires `status = 'Approved'` (else 409 `not_approved`, audited). No payment execution. Separation of duties (same manager may decide and pay): DECISION REQUIRED | `src/endpoints/claimsInsurer.ts` |
| Rate limiting | IMPLEMENTED (per IP) | IMPLEMENTED: per IP on `/api/*` before authentication and per actor (`actor:<role>:<id>`) on `/api/v1/*` after it, same `RATE_LIMITER` binding. Still approximate | `src/index.ts` |
| Security headers / CORS | IMPLEMENTED | IMPLEMENTED; CORS `allowHeaders` reduced to `Content-Type`, `Authorization` | `src/index.ts` |
| Request correlation | `requestId()` middleware | Request ids are generated server-side (`crypto.randomUUID()` in `index.ts`), returned as `X-Request-Id` and stored in `audit_events.request_id`; never taken from an inbound header | `src/index.ts`, `src/security/audit.ts` |
| Tests | 9 files, 85 tests | 12 files, 183 passed + 1 todo (`npm test` on 2026-09-26; TENANT-004 evidence isolation BLOCKED: no evidence endpoint). New: `auth.test.ts`, `tenant.test.ts`, `migration.test.ts`; `actor.test.ts` migrated to JWT with all Phase 0 assertions kept and dev headers proven ignored | `test/` |
| Secrets in repo | None | None. `JWT_SECRET` lives in gitignored `.dev.vars` (local) or `wrangler secret put` (deployed); `.dev.vars.example` holds `CHANGE_ME`; `postman/*.postman_environment.json` is gitignored | `.gitignore` |

### 2b. Phase 2 update (supersedes the "Evidence upload/storage" row above)

| Capability | Phase 1 | Phase 2 | Evidence |
|---|---|---|---|
| Evidence upload/storage | NOT IMPLEMENTED (endpoint only queued an event; `evidence` table existed but was unused) | IMPLEMENTED: private R2 storage (`EVIDENCE_BUCKET`, no public URL), server-generated storage key, allowlisted MIME type + magic-byte check, 10 MB cap, sanitized display filename, backend SHA-256 hash, tenant/uploader/claim id all server-derived. Authorized download and `VALID`/`TAMPERED` integrity verification. TESTED/PASSED (`test/evidence.test.ts`, 15/15) | `src/endpoints/evidence.ts`, `src/security/evidence.ts`, `migrations/0004_evidence_security.sql` |

## 3. Configuration and environment variables

| Name | Where | Required | Purpose |
|---|---|---|---|
| `DB` | `wrangler.toml` D1 binding | Yes | Database |
| `CLAIM_EVENTS` | `wrangler.toml` queue producer | Yes (code tolerates absence) | Claim events |
| `RATE_LIMITER` | `wrangler.toml` `[[ratelimits]]` | Recommended (middleware skips if absent) | Throttling |
| `ALLOWED_ORIGINS` | `wrangler.toml` `[vars]` (default empty), `.dev.vars` | Optional | CORS allowlist, comma-separated |
| `JWT_SECRET` (Phase 1) | **Secret binding only**: `.dev.vars` locally (written by `npm run setup:local`), `wrangler secret put JWT_SECRET` when deployed. Never `wrangler.toml` | Yes (>= 32 bytes) | HS256 signing secret. Missing or short → every request 401, `auth misconfigured` logged |
| `JWT_ISSUER` (Phase 1) | `wrangler.toml` `[vars]` = `easyclaim-dev`; `.dev.vars` may override | Yes | Expected `iss` claim. Missing → every request 401 |
| `JWT_AUDIENCE` (Phase 1) | `wrangler.toml` `[vars]` = `easyclaim-api`; `.dev.vars` may override | Yes | Expected `aud` claim. Missing → every request 401 |
| `ALLOW_DEV_ACTOR_HEADERS` (Phase 0 only) | Was `.dev.vars` **only** | Was local dev/testing only | Phase 0: enabled the spoofable `X-Dev-Actor-*` stub and was never to be set in a deployed environment. **Phase 1 update: REMOVED** together with the stub; the variable is no longer read anywhere and setting it has no effect (`actor.test.ts`, `auth.test.ts` AUTH-011) |

The `database_id` in `wrangler.toml` is a resource identifier, not a secret. Phase 1 update: `wrangler.toml` has no per-environment section (`[env.production]`) yet (NOT IMPLEMENTED); `JWT_ISSUER` / `JWT_AUDIENCE` must be changed per environment by hand, and key rotation is NOT IMPLEMENTED.

## 4. Endpoint inventory (31 routes: 24 from Phase 0, 7 added in Phase 1)

Legend: "Actor" means an actor is resolved by `requireActor`. All `/api/v1/*` routes return 401 without one. Phase 1 update: `requireActor` now means a verified bearer JWT (`Authorization: Bearer <JWT>`, `src/security/actor.ts`); "actor" in both tables has that meaning. Route count from the code: `gateway` 4, `policy` 3, `claims` 10, `claimsInsurer` 6, `ocr` 1, `identity` 5, `audit` 2.

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
| 11 | PATCH | `/api/v1/claims/:claimId/screening` | Wizard step 3 | none (no-op) → actor | CUSTOMER (owner) | claim | `causeOfLoss` (≤2000), `incidentDate` (ISO, not future) | `status`, `message` | UPDATE claim; audit; Info Needed→Screening transition | narrative text (not logged to audit) | Editable only in `Draft`/`Info Needed`. Phase 1 update: the stage precondition is repeated in the SQL (`UPDATE ... WHERE stage IN ('Draft','Info Needed')`, 0 rows → 409) so a concurrent transition cannot slip in between the read and the write | `massAssignment.test.ts`, `bola.test.ts`, `claimLifecycle.test.ts`, `tenant.test.ts` (STATE-006) |
| 12 | POST | `/api/v1/claims/:claimId/evidence-ocr` | Wizard step 4 (OCR queue trigger, no file) | none → actor | CUSTOMER (owner) | claim | — (no file accepted) | `status`, `message` (202) | queue `ClaimEvidenceUploaded`; audit `claim.evidence_queued` | none | Unrelated to real upload/storage, which is now routes 32–35 (§4b) | `bola.test.ts` |
| 13 | POST | `/api/v1/claims/:claimId/submit` | Wizard step 5 | none → actor | CUSTOMER (owner) | claim | — | `status`, `message`, `claimId` | Draft→Submitted (conditional UPDATE); queue `ClaimSubmitted`; audit | none | Requires completed screening; replay gives 409 | `claimLifecycle.test.ts`, `bola.test.ts` |
| 14 | GET | `/api/v1/claims/:claimId/timeline` | Tracking | none (fake data) → actor | owner CUSTOMER, ASSESSOR, MANAGER. Phase 1: insurer staff only for their own tenant, never for a Draft | claim + its audit rows | — | `claimId`, `currentStage`, `timeline[]` | none | claim stage | Insurer read has no tenant scoping (see gaps). Phase 1 update: tenant-scoped through `loadAuthorizedClaim('read')`; a stage is `completed` when the audit trail shows it was reached or the claim is at/after it on the main path | `bola.test.ts`, `claimLifecycle.test.ts`, `tenant.test.ts` (TENANT-001, TENANT-003b) |
| 15 | GET | `/api/v1/claims/:claimId/decision` | Decision status | none → actor | owner CUSTOMER, ASSESSOR, MANAGER. Phase 1: insurer staff only for their own tenant | claim | — | `decision` | none | decision outcome | Read-only. Phase 1 update: tenant-scoped; returns `claims.status` once the stage is Decision/Paid, else `pending` | `bola.test.ts`, `tenant.test.ts` (TENANT-003) |
| 16 | POST | `/api/v1/claims/:claimId/appeal` | Appeal a rejection | none → actor | CUSTOMER (owner) | claim | `reason` (≤2000) | `status` | Decision→Appeal; audit | none | Only when `stage=Decision` and `status=Rejected` | `claimLifecycle.test.ts`, `bola.test.ts` |
| 17 | POST | `/api/v1/ocr/process` | OCR stub | none → actor | ASSESSOR, MANAGER | none | — | `extracted` | none | none | Stub; no OCR engine | `rbac.test.ts` |
| 18 | GET | `/api/v1/profile` | Profile | none → actor | any | none | — | `profile{}` | none | none | Stub (empty) | `actor.test.ts` |
| 19 | PATCH | `/api/v1/profile` | Update profile | none → actor | any | none | ignored | `updated:true` | **none** (no-op) | — | Stub returns success without doing anything | NOT TESTED |
| 20 | GET | `/api/v1/profile/consent` | Consent state | none → actor | any | none | — | `consent:true` | none | — | Hard-coded `true`; POPIA consent NOT IMPLEMENTED | NOT TESTED |
| 21 | GET | `/api/v1/profile/mandates/:tenantId/check` | Debit mandate check | none → actor | any | `tenantId` (unchecked) | — | `active:true` | none | — | **No object check** on `tenantId` (stub) | NOT TESTED |
| 22 | POST | `/api/v1/profile/mandates/cancel` | Cancel mandate | none → actor | CUSTOMER | none | ignored | `cancelled:true` | audit `mandate.cancel_requested` | — | Stub; no step-up auth | `rbac.test.ts` |
| 23 | GET | `/api/v1/activities/history` | History | none → actor | any | none | — | `history[]` (empty) | none | — | Stub | `actor.test.ts` |
| 24 | GET | `/api/v1/activities/audit-trail` | Audit trail | none → actor | any | none | — | `trail[]` (empty) | none | — | Stub. Does **not** read `audit_events`. If wired up, restrict it to insurer/admin roles | `actor.test.ts` |

### 4a. Phase 1 endpoints (routes 25–31)

All seven require a verified bearer token. Middleware order on the insurer routes (26–31): `requireActor` → coarse `requireRole('ASSESSOR', 'MANAGER')` → strict zod validation → `loadAuthorizedClaim(c, claimId, 'insurer')` (load → tenant → ownership → mode; 404 otherwise) → `transitionClaim` → audit. `/pay` is a state transition only; no money moves.

| # | Method | Path | Purpose | Auth | Role | Object accessed | Request fields | Response fields | Side effects | Sensitive data | Security concerns / notes | Tests |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 25 | GET | `/api/v1/claims` | List claims | actor (JWT) | CUSTOMER: own claims; ASSESSOR/MANAGER: claims of `actor.tenantId` with `stage <> 'Draft'`; ADMIN → 403 + audit `authz.role_denied` | claims by `user_id` or by `tenant_id` | `?limit` 1..50 (default 20, coerced; out of range → 400; the query schema is not `.strict()`, so other query parameters are ignored) | `claims[]` with `id, policy_id, tenant_id, stage, status, category, created_at, updated_at` (no `user_id`) | none | claim ids and stages | Bounded page size; insurer list omits the platform-wide `user_id` (DECISION REQUIRED: per-tenant claimant reference); no cursor pagination | `tenant.test.ts` (TENANT-001b, TENANT-006); live log "Tenant-scoped lists" |
| 26 | POST | `/api/v1/claims/:claimId/verify` | Submitted → Verified | actor (JWT) | ASSESSOR, MANAGER of the claim's tenant | claim | — | `status`, `claimId`, `from`, `to` | conditional `UPDATE` + audit `claim.stage_changed` in one D1 batch | none | Cross-tenant / Draft / missing → 404 + audit `authz.claim_access_denied`; wrong stage → 409 `illegal_transition`; lost race or replay → 409 `stale_state` | `tenant.test.ts` (STATE-001/002/004, TENANT-002, RBAC-001/002); live log ATTACK-P1-006/007 |
| 27 | POST | `/api/v1/claims/:claimId/screen` | Verified → Screening | actor (JWT) | ASSESSOR, MANAGER of the claim's tenant | claim | — | `status`, `claimId`, `from`, `to` | as 26 | none | Stage change only; no screening or fraud logic exists | `tenant.test.ts` (STATE-001, TENANT-002) |
| 28 | POST | `/api/v1/claims/:claimId/review` | Screening → Review; Appeal → Review | actor (JWT) | ASSESSOR, MANAGER of the claim's tenant; Appeal → Review is MANAGER-only (ASSESSOR → 403 `forbidden`, audited `role_not_permitted`) | claim | — | `status`, `claimId`, `from`, `to` | as 26 | none | No review record is written | `tenant.test.ts` (STATE-001, STATE-005, TENANT-002) |
| 29 | POST | `/api/v1/claims/:claimId/request-info` | Screening / Review → Info Needed | actor (JWT) | ASSESSOR, MANAGER of the claim's tenant | claim | — | `status`, `claimId`, `from`, `to` | as 26 | none | The customer answers through route 11, which moves the claim back to Screening; no expiry job exists for Info Needed → Expired | `tenant.test.ts` (STATE-006, TENANT-002) |
| 30 | POST | `/api/v1/claims/:claimId/decide` | Review → Decision | actor (JWT) | ASSESSOR, MANAGER of the claim's tenant | claim | `outcome` (`Approved` \| `Rejected`, strict; extra or unknown fields → 400) | `status`, `claimId`, `from`, `to`, `outcome` | `UPDATE claims SET stage, status` in one statement + audit with `outcome` | decision outcome | No amount, reason, decision record or four-eyes check (DECISION REQUIRED: separation of duties) | `tenant.test.ts` (STATE-001, STATE-005, TENANT-002b, "decide rejects invalid or extra fields"); live log ATTACK-P1-006/007 |
| 31 | POST | `/api/v1/claims/:claimId/pay` | Decision → Paid | actor (JWT) | MANAGER of the claim's tenant (ASSESSOR → 403 via the state machine) | claim | — | `status`, `claimId`, `from`, `to` | conditional `UPDATE` + audit; 409 `not_approved` when `status` is not `Approved`, audited as `claim.transition_rejected` | none | **State transition only: no payment is executed and no bank details exist.** The same manager may decide and pay (DECISION REQUIRED) | `tenant.test.ts` (STATE-001/003/004/005, TENANT-002/002b); live log ATTACK-P1-008 and happy path |

### 4b. Phase 2 endpoints (routes 32–35): evidence upload, storage and integrity

All four require a verified bearer token and go through `loadAuthorizedClaim` first (404 for missing, cross-tenant, other-customer or Draft-for-insurer claims, same as every other `:claimId` route). See `docs/phase-reports/PHASE_02_REPORT.md` for the full flow.

| # | Method | Path | Purpose | Role | Object accessed | Request fields | Response fields | Side effects | Sensitive data | Security concerns / notes | Tests |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 32 | GET | `/api/v1/claims/:claimId/evidence` | List evidence metadata | owner CUSTOMER, or ASSESSOR/MANAGER of the claim's tenant | claim (`read`) | — | `evidence[]`: `id, display_name, mime_type, size_bytes, sha256, created_at` | none | filenames, hashes | `uploaded_by` and `storage_key` are never returned | `evidence.test.ts` |
| 33 | POST | `/api/v1/claims/:claimId/evidence` | Upload a file | CUSTOMER (owner), claim stage `Draft`/`Info Needed` | claim (`owner-write`) | `multipart/form-data`, field `file` (≤10 MB, `application/pdf`/`image/jpeg`/`image/png`, magic bytes must match) | `status`, `evidenceId`, `sha256` (201) | `EVIDENCE_BUCKET.put`; INSERT `evidence`; audit `evidence.uploaded`/`evidence.rejected`; queues `ClaimEvidenceUploaded` | file bytes, hash | Owner/tenant/claim id are server-derived, never read from the form body (tested); wrong stage → 409; unsupported/mismatched type → 415; oversized → 413 | `evidence.test.ts` |
| 34 | GET | `/api/v1/claims/:claimId/evidence/:evidenceId` | Download the original bytes | owner CUSTOMER, or ASSESSOR/MANAGER of the claim's tenant | claim (`read`) + evidence row matched by `id AND claim_id` | — | file bytes, `Content-Type`, `Content-Disposition` (sanitized filename) | audit `evidence.accessed` | file bytes | Server-controlled retrieval only; no public/predictable URL | `evidence.test.ts` |
| 35 | GET | `/api/v1/claims/:claimId/evidence/:evidenceId/verify` | Integrity check | owner CUSTOMER, or ASSESSOR/MANAGER of the claim's tenant | claim (`read`) + evidence row | — | `status: VALID \| TAMPERED`, `expectedHash`, `actualHash` | audit `evidence.integrity_verified` (`outcome: success` when valid, else `failure`) | hashes | Recomputes SHA-256 over the stored object; detects modification, does not itself gate access | `evidence.test.ts` |

Queue consumer (`queue()` in `src/index.ts` → `processQueueBatch` in `src/endpoints/ocr.ts`): validates message shape and acks malformed messages. It now handles `ClaimEvidenceUploaded`, which was previously silently dropped. Tested in `test/queue.test.ts`. Under `wrangler dev` the local consumer did **not** fire, both before and after the changes, so it has not been verified live. Phase 1 update: re-observed during the Phase 1 live run, still no consumer log lines under `wrangler dev`; still not verified live.

## 5. Existing security controls found at baseline (`efb6cc3`)

- Parameterised SQL in `PolicyModel.getMyCovers`. That was the only control.

## 6. Missing or uncertain controls (after cyber branch)

- Real authentication (tokens, sessions, IdP): NOT IMPLEMENTED. Owned by the backend team. **Phase 1 update:** app-verified HS256 bearer JWT is IMPLEMENTED (section 2a). Still open: identity provider / JWKS verification (PLANNED, `hono/jwt` `verifyWithJwks`), revocation / `jti` denylist (PLANNED), key rotation (NOT IMPLEMENTED), per-environment wrangler config (NOT IMPLEMENTED).
- Tenant/insurer scoping: ASSESSOR/MANAGER can read **any** claim. There is no organisation model. **Phase 1 update:** IMPLEMENTED (`tenants` table, `tenant_id` on policies and claims, tenant boundary in `loadAuthorizedClaim`). Open: tenant admin functions (NOT IMPLEMENTED), ADMIN scope and per-tenant claimant reference (DECISION REQUIRED), evidence tenant isolation (BLOCKED: no evidence resource exists).
- Insurer workflow endpoints (verify, screen, request info, decide, pay): NOT IMPLEMENTED. **Phase 1 update:** IMPLEMENTED as state transitions (section 4a). Decision records (amount/reason) and payment execution remain NOT IMPLEMENTED; separation of duties and an appeal count limit are DECISION REQUIRED; Withdrawn (endpoint) and Expired (job) remain NOT IMPLEMENTED.
- Evidence upload, storage, hashing, file validation: NOT IMPLEMENTED. (Unchanged in Phase 1.)
- OCR/AI: NOT IMPLEMENTED. (Unchanged in Phase 1.)
- Payout, step-up auth, configuration management/versioning: NOT IMPLEMENTED. **Phase 1 update:** payout is a PARTIAL state transition only (route 31); step-up auth and configuration management unchanged.
- Profile, consent, mandate endpoints are stubs. `mandates/:tenantId/check` has no object check. (Unchanged in Phase 1: the route still ignores its `tenantId` parameter.)
- Rate limiting is per IP and approximate (by design of the binding). There are no per-user or per-operation limits. **Phase 1 update:** a per-actor limit after authentication was added on the same binding; still approximate, still no per-operation limits.
- Queue consumer not verified under `wrangler dev`. (Re-observed in Phase 1: still no consumer log lines.)
- Phase 1 note, carried over from Phase 0 unchanged: the `audit_events` append-only triggers can be dropped by a database admin. The application never updates or deletes audit rows, but the table is not protected against DB-level access.

## 7. Verification evidence

- `npm run typecheck`: pass.
- `npm test`: 9 files, 85 tests, TESTED/PASSED.
- Mutation check: disabling the ownership check in `loadAuthorizedClaim` made 5 BOLA tests fail, as expected. Restored afterwards.
- `npm audit`: 0 vulnerabilities.
- Live `wrangler dev` checks: no actor → 401; IDOR → 404; customer → `/ocr/process` 403; mass assignment → 400; replay submit → 409; burst of 120 requests → 7 × 429.

Phase 1 update (`cb2588a` / working tree, re-run 2026-09-26):

- `npm run typecheck`: pass.
- `npm test`: 12 files, 183 passed + 1 todo (TENANT-004 evidence isolation, BLOCKED). New files: `auth.test.ts` (AUTH-001..014), `tenant.test.ts` (TENANT-001..007, STATE-001..006, RBAC-001/002, AUDIT-001), `migration.test.ts` (0003 backfill by id only, idempotent, `tenant_id` references `tenants`). `actor.test.ts` migrated to JWT with the Phase 0 assertions kept and the dev headers proven ignored. Tests mint real HS256 tokens with a per-run random secret (`vitest.config.mts`).
- `npm audit`: 0 vulnerabilities.
- Live `wrangler dev` attack run: `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` (ATTACK-P1-001 to -012: forged, expired, tampered, `alg=none`, HS512 and over-TTL tokens → 401; cross-tenant read and transitions → 404, indistinguishable from a missing claim; customer on insurer routes and ADMIN list → 403; assessor payout → 403; retired dev headers → 401 without a token and ignored with one; IDOR → 404; tenant-scoped lists; full Submitted → Verified → Screening → Review → Decision → Paid path with pay-before-decision and pay-again → 409; audit rows per action, role and tenant counted).
