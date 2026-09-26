# Security Test Plan

Run automated tests:

```bash
cd backend
npm install
npm test            # Phase 1: 12 files, 175 passed + 1 todo (TENANT-004, BLOCKED) on branch cyber (working tree)
npm run typecheck   # tsc --noEmit, clean
npm audit           # 0 vulnerabilities
```

Phase 0 baseline was 9 files / 85 tests. Phase 1 added `test/auth.test.ts` (AUTH-001..014), `test/tenant.test.ts` (TENANT-001..007, STATE-001..006, RBAC-001/002, AUDIT-001) and `test/migration.test.ts`, and migrated `test/actor.test.ts` to JWT (every Phase 0 assertion kept).

**Phase 1 update — manual tests.** The Phase 0 `X-Dev-Actor-*` header stub and `ALLOW_DEV_ACTOR_HEADERS` are REMOVED; every `/api/v1/*` request needs `Authorization: Bearer <JWT>` (HS256, `iss`/`aud` pinned, see `backend/src/security/actor.ts`). Local setup:

```bash
cd backend
npm run setup:local                 # scripts/setup-dev-vars.mjs: creates .dev.vars with a random JWT_SECRET (never overwrites)
npm run db:migrate:local && npm run db:seed:local && npm run dev   # http://127.0.0.1:8787
npm run token -- --demo             # scripts/mint-token.mjs: one token per demo actor (refuses out-of-policy claims)
npm run token -- --sub user123 --role CUSTOMER
npm run token -- --sub assessor_a1 --role ASSESSOR --tenant ins_discovery
npm run token -- --postman          # writes backend/postman/EasyClaim.local.postman_environment.json (gitignored)
```

Postman: `backend/EasyClaim.postman_collection.json` reads the bearer tokens from that generated environment file; folders `0 - Unauthenticated (expect 401)`, `5 - Cross-tenant attack (expect 404)`, `6 - Role attacks (expect 403)` and `7 - Token attacks (expect 401)` are attack demos. `JWT_ISSUER` / `JWT_AUDIENCE` live in `backend/wrangler.toml` `[vars]`; `JWT_SECRET` is a secret (`.dev.vars` locally, `wrangler secret put JWT_SECRET` deployed). If any of the three is missing the API answers 401 to everything (fail closed).

Seed actors (Phase 1, see `backend/test/helpers.ts` and `scripts/mint-token.mjs` `DEMO_ACTORS`): `user123` (CUSTOMER, no tenant, owns `claim_disc_101` in Review [tenant `ins_discovery`] and `claim_sanlam_102` in Decision/Approved [tenant `ins_sanlam`]), `user456` (CUSTOMER, owns no claims), `assessor_a1` / `manager_a1` (tenant A `ins_discovery`), `assessor_b1` / `manager_b1` (tenant B `ins_sanlam`), `admin1` (ADMIN, no tenant, no claim access). `claim_mom_103` (tenant C `ins_momentum`, Submitted) is used as a third-tenant target.

Live Phase 1 evidence (all ATTACK-P1 scenarios run against `wrangler dev`): `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log`.

Status vocabulary: TESTED/PASSED · TESTED/FAILED · PARTIAL · NOT TESTED · BLOCKED (feature missing) · DECISION REQUIRED.

## Authentication

| ID | Test | Method | Status |
|---|---|---|---|
| AUTHN-01 | No credentials → 401, body exactly `{"error":"unauthenticated"}`, `WWW-Authenticate: Bearer` | Phase 0: `test/actor.test.ts` "401 when no actor headers are sent". Phase 1 update: `test/actor.test.ts` "401 when no credentials are sent"; `test/auth.test.ts` "AUTH-001 no token → 401 with WWW-Authenticate" | TESTED/PASSED |
| AUTHN-02 | Dev headers ignored → 401 | Phase 0: "401 when the dev flag is off…". Phase 1 update (stub REMOVED entirely): `test/actor.test.ts` "401 for the retired dev headers, with or without the old flag"; `test/auth.test.ts` "AUTH-011 dev actor headers never bypass authentication (ATTACK-P1-010)" (also proves headers do not override a real token's identity: customer + manager headers → 403) | TESTED/PASSED |
| AUTHN-03 | Invalid role → 401 | Phase 1 update: `test/actor.test.ts` "401 for an unknown role in a correctly signed token"; `test/auth.test.ts` "AUTH-006 rejects unknown role → 401" | TESTED/PASSED |
| AUTHN-04 | Malformed actor id (SQL-like) → 401 | Phase 1 update: `test/actor.test.ts` "401 for a malformed actor id in a correctly signed token"; `actorFromClaims` "rejects malformed sub" | TESTED/PASSED |
| AUTHN-05 | Every route (`/client/home`, `/covers/market-catalog`, `/claims`, `/claims/status`, `/profile`, `/activities/history`, `/activities/audit-trail`) requires an actor (`requireActor` is mounted on `/api/v1/*` in `src/index.ts`) | `test/actor.test.ts` "%s requires an actor" (7 routes; Phase 1 adds `GET /claims`) | TESTED/PASSED |
| AUTHN-06 | Invalid credentials: malformed / non-JWT / wrong scheme / wrong number of segments / token in query string / two headers → 401 | Phase 1 update: `test/auth.test.ts` "AUTH-002 malformed token (%s) → 401" (7 cases), "AUTH-002b header parsing: scheme without a space, two headers, and query-string tokens are rejected", "AUTH-005b bearer scheme is case-insensitive, token is not" | TESTED/PASSED (was BLOCKED in Phase 0) |
| AUTHN-07 | Expired token → 401; a token that was valid stops working once `exp` passes | Phase 1 update: `test/auth.test.ts` "AUTH-003 expired token → 401", "AUTH-008 token reuse after expiry → 401 (ATTACK-P1-009)"; `test/actor.test.ts` `actorFromClaims` "rejects expired" (`exp <= now`). Live: ATTACK-P1-002, ATTACK-P1-009 in `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` | TESTED/PASSED (was BLOCKED in Phase 0) |
| AUTHN-08 | Bad signature / tampered payload / `alg:none` / algorithm confusion (HS512 against pinned HS256) → 401 | Phase 1 update: `test/auth.test.ts` "AUTH-004 wrong signing key → 401", "AUTH-004b tampered payload (role escalation) → 401", "AUTH-004c alg=none → 401", "AUTH-004d HS512 token against pinned HS256 → 401". Live: ATTACK-P1-001, -003, -004, -004b, -004c | TESTED/PASSED (was BLOCKED in Phase 0) |
| AUTHN-09 | Brute-force login throttled | — (there is still no login endpoint; tokens are minted offline by `scripts/mint-token.mjs` or, later, an IdP). Per-actor request throttling after auth is covered by RATE-06 | BLOCKED (no login) |
| AUTHN-10 | Phase 1 update — claim policy: missing/wrong `iss`, missing/wrong `aud`, missing `exp`, missing `iat`, `iat`/`nbf` in the future, missing `sub`, missing role, customer lifetime > 24 h, customer token carrying `tenant_id` → 401 | `test/auth.test.ts` "AUTH-006 rejects %s → 401" (13 cases) | TESTED/PASSED |
| AUTHN-11 | Phase 1 update — insurer staff token without `tenant_id` → 401; staff lifetime > 8 h → 401, ≤ 8 h accepted | `test/auth.test.ts` "AUTH-006b insurer token without tenant_id → 401", "AUTH-006c staff token with a lifetime above the 8h maximum → 401". Live: ATTACK-P1-004d (9 h manager token → 401) | TESTED/PASSED |
| AUTHN-12 | Phase 1 update — `aud` may be an array that contains the API audience | `test/auth.test.ts` "AUTH-007 audience may be an array containing the API" | TESTED/PASSED |
| AUTHN-13 | Phase 1 update — misconfiguration fails closed: missing or < 32-byte `JWT_SECRET`, missing `JWT_ISSUER`, empty `JWT_AUDIENCE` → 401 even for a well-formed token | `test/auth.test.ts` "AUTH-009 missing or short JWT_SECRET fails closed even for a well-formed token", "AUTH-010 missing issuer/audience configuration fails closed" | TESTED/PASSED |
| AUTHN-14 | Phase 1 update — 401 body is exactly `{"error":"unauthenticated"}`; server logs carry only the hono error class name (`token rejected: Jwt…`) and never the token | `test/auth.test.ts` "AUTH-012 401 responses reveal nothing about the token or the failure", "AUTH-013 server logs never contain the token › for a %s token" (expired, bad signature, wrong audience) | TESTED/PASSED |
| AUTHN-15 | Phase 1 update — no audit row (no pre-auth DB write) for unauthenticated requests | `test/auth.test.ts` "AUTH-014 no audit row is written for unauthenticated requests (no pre-auth DB writes)" | TESTED/PASSED |
| AUTHN-16 | Phase 1 update — pure claim validation matrix (`validateClaims`): exp/iat required, per-role TTL cap (24 h customer / 8 h staff, boundary accepted), sub/tenant `ID_PATTERN`, role case-sensitive, customer must not carry a tenant, ASSESSOR/MANAGER must, null/string payloads rejected | `test/actor.test.ts` "actorFromClaims (pure claim validation)": "accepts a customer without tenant", "accepts insurer staff with tenant", "rejects %s" (18 cases), "accepts a staff token at exactly the 8h maximum and a customer token at exactly 24h" | TESTED/PASSED |
| AUTHN-17 | Phase 1 — ADMIN may omit or carry `tenant_id` | `test/actor.test.ts` "admin may omit tenant (DECISION REQUIRED: platform vs tenant admin)"; `test/tenant.test.ts` "TENANT-001b an ADMIN token carrying a tenant still gets no claim or list access" | TESTED/PASSED — semantics DECISION REQUIRED |
| AUTHN-18 | IdP / JWKS verification (`hono/jwt verifyWithJwks`, asymmetric keys) | — documented as the future path in `src/security/actor.ts`, NOT IMPLEMENTED | NOT TESTED |
| AUTHN-19 | Token revocation / `jti` denylist | — PLANNED, NOT IMPLEMENTED (bounded lifetime is the compensating control) | NOT TESTED |
| AUTHN-20 | Signing-key rotation (old and new secret accepted during a rollover) | — NOT IMPLEMENTED (single `JWT_SECRET`) | NOT TESTED |

## Authorization

| ID | Test | Method | Status |
|---|---|---|---|
| AUTHZ-01 | Customer B reads A's timeline → 404, no data leaked | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-02 | Customer B reads A's decision → 404 | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-03 | Customer B submits/screens/uploads/appeals A's claim → 404 | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-04 | Denied vs non-existent claim responses identical | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-05 | Denied access writes `authz.claim_access_denied` | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-06 | `my-covers` returns only caller's policies | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-07 | Cannot initiate claim on another's policy → 422 | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-08 | `verify-eligibility` does not confirm another's policy | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-09 | Customer → insurer function `/ocr/process` → 403 + audit | `test/rbac.test.ts` | TESTED/PASSED |
| AUTHZ-10 | Insurer roles blocked from customer-only routes → 403 | `test/rbac.test.ts` | TESTED/PASSED |
| AUTHZ-11 | ADMIN cannot read claims | `test/rbac.test.ts` | TESTED/PASSED |
| AUTHZ-12 | Assessor can read but not act as customer | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-13 | Assessor accessing admin functionality | — | BLOCKED (no admin endpoints) |
| AUTHZ-14 | Unauthorized configuration change | — | BLOCKED (no config endpoints) |
| AUTHZ-15 | Assessor of insurer X reads claim of insurer Y | Phase 1 update: tenant model added (`migrations/0003_tenants.sql`, `loadAuthorizedClaim` load → tenant → ownership → mode). `test/tenant.test.ts` "TENANT-001 tenant B assessor cannot read a tenant A claim (404, audited as cross_tenant)". Live: ATTACK-P1-005 | TESTED/PASSED (was BLOCKED in Phase 0) |

### Phase 1 update — tenant isolation (`test/tenant.test.ts`)

Seed tenants: A = `ins_discovery` (`claim_disc_101`, Review), B = `ins_sanlam` (`claim_sanlam_102`, Decision/Approved), C = `ins_momentum` (`claim_mom_103`, Submitted). Denials are 404 `{"error":"not_found"}` with an `authz.claim_access_denied` row whose `details` carry `{mode, exists, reason}` and name only the actor's own context.

| ID | Test | Method | Status |
|---|---|---|---|
| TENANT-001 | Tenant B assessor reads tenant A timeline → 404, body contains no owner id; one audit row `reason: cross_tenant`, `exists: true`, `actor_tenant_id: ins_sanlam`; the row never names `ins_discovery` or `user123` | "TENANT-001 tenant B assessor cannot read a tenant A claim (404, audited as cross_tenant)" | TESTED/PASSED |
| TENANT-001b | ADMIN token carrying `tenant_id` still gets no claim (404), no list (403), no transition (403) | "TENANT-001b an ADMIN token carrying a tenant still gets no claim or list access" | TESTED/PASSED |
| TENANT-001c | Draft claims are invisible to insurer staff of the same tenant (timeline 404, verify 404, absent from `GET /claims`, audit `reason: draft`) | "TENANT-001c unsubmitted drafts are invisible to insurer staff of the same tenant" | TESTED/PASSED |
| TENANT-002 | Tenant A assessor and manager call every insurer route (`verify`, `screen`, `review`, `request-info`, `pay`, `decide`) on a tenant C claim → 11 × 404, stage/status unchanged, zero `claim.stage_changed`, 11 denials all `cross_tenant` | "TENANT-002 tenant A staff cannot transition a tenant C claim through any insurer route; stage unchanged" | TESTED/PASSED |
| TENANT-002b | Tenant B manager cannot decide or pay a tenant A claim → 404, stage unchanged | "TENANT-002b tenant B manager cannot decide or pay a tenant A claim". Live: ATTACK-P1-006 | TESTED/PASSED |
| TENANT-003 | Tenant B assessor reads tenant A decision → 404 | "TENANT-003 tenant B assessor cannot read a tenant A decision" | TESTED/PASSED |
| TENANT-003b | Cross-tenant and non-existent claim responses are identical (no existence oracle across tenants) | "TENANT-003b cross-tenant and non-existent claims are indistinguishable". Live: ATTACK-P1-005 compare line | TESTED/PASSED |
| TENANT-004 | Evidence resource isolation across tenants | `it.todo` "TENANT-004 evidence resource isolation — BLOCKED: no evidence endpoint or stored evidence exists yet" | BLOCKED (no evidence endpoint or storage) |
| TENANT-005 | Claim with `tenant_id NULL` is visible to no insurer (timeline/verify 404, audit `reason: tenant_unset`); owner still reads it | "TENANT-005 a claim with no tenant is visible to no insurer (fail closed)" | TESTED/PASSED |
| TENANT-006 | `GET /api/v1/claims`: assessor A gets exactly `tenant_id = ins_discovery AND stage <> 'Draft'`, assessor B likewise for `ins_sanlam`, customer gets exactly `user_id = user123`; `user_id` never in any list body; ADMIN → 403; `?limit=500` → 400 (bounded 1..50, default 20) | "TENANT-006 list endpoint is scoped per tenant / per owner". Live: "Tenant-scoped lists" block in the evidence log | TESTED/PASSED |
| TENANT-007 | `POST /claims/initiate` copies `tenant_id` from the policy (never from the client); policy without tenant → 422 `policy_not_eligible`, audit `claim.initiate_rejected` `reason: policy_missing_tenant` | "TENANT-007 initiate copies tenant from the policy; a policy without tenant is not eligible" | TESTED/PASSED |

### Phase 1 update — function-level checks on the new insurer routes (`test/tenant.test.ts`)

| ID | Test | Method | Status |
|---|---|---|---|
| RBAC-001 | Customer calls `verify`, `screen`, `review`, `request-info`, `pay`, `decide` on their own claim → 403 (coarse `requireRole('ASSESSOR','MANAGER')` runs before the claim is loaded, so no claim data or existence leaks); stage unchanged | "RBAC-001 customers cannot call insurer transitions (403, no claim data)". Live: ATTACK-P1-007 | TESTED/PASSED |
| RBAC-002 | ADMIN calls `decide` → 403 (ADMIN is in no transition) | "RBAC-002 admin cannot transition claims". Live: ATTACK-P1-012 | TESTED/PASSED |

## Object property (mass assignment)

| ID | Test | Method | Status |
|---|---|---|---|
| PROP-01..06 | Screening with `stage`, `status`, `riskScore`, `decision`, `approvedBy`, `user_id` → 400, row unchanged | `test/massAssignment.test.ts` | TESTED/PASSED |
| PROP-07 | Initiate with `stage`/`userId` → 400 | `test/massAssignment.test.ts` | TESTED/PASSED |
| PROP-08 | Join-request with `userId` → 400; body not echoed | `test/massAssignment.test.ts` | TESTED/PASSED |
| PROP-09 | Validation error does not echo input | `test/massAssignment.test.ts` | TESTED/PASSED |
| PROP-10 | Phase 1 update — `POST /:claimId/decide` with `outcome: "Paid"` or an extra `amount` field → 400, stage unchanged (`decideSchema` is `.strict()`, `outcome` ∈ Approved \| Rejected) | `test/tenant.test.ts` "decide rejects invalid or extra fields (mass assignment)" | TESTED/PASSED |

## State machine

| ID | Test | Method | Status |
|---|---|---|---|
| STATE-01 | 12 legal transitions allowed | `test/stateMachine.test.ts` | TESTED/PASSED |
| STATE-02 | Illegal: Submitted→Paid, Screening→Paid, Screening→Decision (skip review), Verified→Review (skip screening), terminal states | `test/stateMachine.test.ts` | TESTED/PASSED |
| STATE-03 | Role: Customer→Decision, Customer→Paid, Assessor→Paid, Admin→any rejected | `test/stateMachine.test.ts` | TESTED/PASSED |
| STATE-04 | Only MANAGER can reach Paid; ADMIN in no transition | `test/stateMachine.test.ts` | TESTED/PASSED |
| STATE-05 | Initiate→screening→submit via API, audited, timeline dated | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-06 | Submit before screening → 422 | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-07 | Double submit (replay) → 409 + `claim.transition_rejected` | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-08 | Claim in Review cannot be resubmitted/edited → 409 | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-09 | Approved decision not appealable; rejected appealable once | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-10 | Unauthorized payout via API | Phase 1 update: `POST /api/v1/claims/:claimId/pay` exists (state transition Decision → Paid only; NO payment execution). Assessor → 403 (`test/tenant.test.ts` "STATE-003 …"), customer → 403 ("RBAC-001 …"), cross-tenant manager → 404 ("TENANT-002b …"), not-yet-decided → 409 `illegal_transition` ("STATE-004 …"), Rejected decision → 409 `not_approved` ("STATE-005 …"). Live: ATTACK-P1-008, happy-path lines "pay before decision", "pay by assessor A", "pay again (replay)" | TESTED/PASSED for the transition guard (was BLOCKED in Phase 0); payment execution itself NOT IMPLEMENTED |

### Phase 1 update — insurer transitions over HTTP (`test/tenant.test.ts`)

Routes: `POST /api/v1/claims/:claimId/verify`, `/screen`, `/review`, `/request-info`, `/decide` (`{outcome: Approved|Rejected}`), `/pay` in `backend/src/endpoints/claimsInsurer.ts`. Order on every route: `requireActor` → coarse `requireRole('ASSESSOR','MANAGER')` → strict zod → `loadAuthorizedClaim(c, id, 'insurer')` → `transitionClaim` (re-asserts owner/tenant, state machine incl. per-transition role, ONE D1 batch: conditional `UPDATE … WHERE id=? AND stage=?` + audit `INSERT … WHERE changes() = 1`; 0 rows → 409 `stale_state`).

| ID | Test | Method | Status |
|---|---|---|---|
| STATE-001 | Full path Submitted → Verified → Screening → Review → Decision(Approved) → Paid with assessor A / manager A; `claims.status` becomes `Approved` in the decide statement; customer `/decision` reads `Approved`; six `claim.stage_changed` rows in order, each with a `request_id`; customer timeline shows every stage completed and dated | "STATE-001 valid role + tenant: full path Submitted → … → Paid, each step audited". Live: "Happy path: Submitted -> Paid" block in the evidence log | TESTED/PASSED |
| STATE-002 | Correct role, wrong tenant (assessor B verifies a tenant A claim) → 404, stage unchanged | "STATE-002 correct role, wrong tenant → 404 and no change" | TESTED/PASSED |
| STATE-003 | Correct tenant, insufficient role: assessor A pays an Approved claim → 403, stage stays Decision, audit `claim.transition_rejected` `{to: Paid, reason: role_not_permitted}` | "STATE-003 correct tenant, insufficient role → 403 (assessor cannot pay), audited". Live: ATTACK-P1-008 | TESTED/PASSED |
| STATE-004 | Illegal edges over HTTP: Submitted → Screening / Review / Decision / Paid → 409, stage unchanged | "STATE-004 illegal transitions are rejected with 409 (skip verification, pay before decision)" | TESTED/PASSED |
| STATE-005 | Rejected decision: `/pay` → `{"error":"not_approved"}`; customer appeal → Appeal; Appeal → Review by assessor → 403 (MANAGER-only), by manager → 200 | "STATE-005 a rejected decision cannot be paid, but can be appealed and re-reviewed by a manager" | TESTED/PASSED |
| STATE-006 | `request-info` from Screening → Info Needed; customer `PATCH /:claimId/screening` (stage precondition repeated in SQL) returns the claim to Screening | "STATE-006 request-info round trip: insurer asks, customer answers, claim returns to Screening" | TESTED/PASSED |
| STATE-11 | Withdrawn (customer) and Expired (SYSTEM) transitions | — state machine only (`test/stateMachine.test.ts`); no endpoint or job exists | BLOCKED (no endpoint/job) |
| STATE-12 | Separation of duties: the same MANAGER may decide and pay | — not enforced | NOT TESTED — DECISION REQUIRED |
| STATE-13 | Appeal count limit (repeated Appeal → Review → Decision → Appeal loops) | — not enforced | NOT TESTED — DECISION REQUIRED |

## Evidence

| ID | Test | Status |
|---|---|---|
| EVID-01 | Evidence event on another's claim → 404 | TESTED/PASSED (`test/bola.test.ts`) |
| EVID-02..06 | Oversized upload, invalid type, path traversal filename, replacement, cross-customer download | BLOCKED — no file upload/storage exists (Phase 1 update: unchanged; `/:claimId/evidence-ocr` still only queues an event) |
| EVID-07 | Phase 1 update — cross-tenant evidence isolation | BLOCKED — `test/tenant.test.ts` `it.todo` TENANT-004 (no evidence endpoint or stored evidence) |

## Resource abuse

| ID | Test | Method | Status |
|---|---|---|---|
| RATE-01 | Limiter denial → 429 | `test/hardening.test.ts` | TESTED/PASSED |
| RATE-02 | Binding configured | `test/hardening.test.ts` | TESTED/PASSED |
| RATE-03 | 120 rapid requests locally → some 429 | Manual curl loop (observed 113×200, 7×429) | TESTED/PASSED |
| RATE-04 | Body > 64 KB → 413 | `test/hardening.test.ts` | TESTED/PASSED |
| RATE-05 | Excessive pagination | Phase 1 update: `GET /api/v1/claims?limit=500` → 400; `limit` bounded 1..50, default 20 (`listQuerySchema`). `test/tenant.test.ts` "TENANT-006 list endpoint is scoped per tenant / per owner" | TESTED/PASSED (was NOT TESTED) |
| RATE-06 | Phase 1 update — per-IP limit before auth, per-actor limit (`actor:<role>:<id>`) after auth on the same `RATE_LIMITER` binding; an actor over its own limit gets 429 even when the IP limit passes; unauthenticated requests never reach the actor limiter | `test/hardening.test.ts` "rate limits per IP before auth and per actor after auth" | TESTED/PASSED (approximate by design, not re-run live in Phase 1) |

## Hardening / leakage

| ID | Test | Method | Status |
|---|---|---|---|
| HARD-01 | Security headers present | `test/hardening.test.ts` | TESTED/PASSED |
| HARD-02 | CORS allows only configured origin | `test/hardening.test.ts` | TESTED/PASSED |
| HARD-03 | Unknown route → JSON 404 | `test/hardening.test.ts` | TESTED/PASSED |
| HARD-04 | Malformed JSON → 400 | `test/hardening.test.ts` | TESTED/PASSED |
| HARD-05 | Internal error → generic 500, no stack/SQL | `test/hardening.test.ts` | TESTED/PASSED |

## AI / OCR

| ID | Test | Status |
|---|---|---|
| AI-01 | Malformed / prompt-like queue message discarded, not retried | TESTED/PASSED (`test/queue.test.ts`) |
| AI-02..04 | Malicious document text, prompt injection in OCR output, AI overriding rules | BLOCKED — no OCR/AI |

## Audit

| ID | Test | Status |
|---|---|---|
| AUD-01 | Sensitive actions produce events (created, stage_changed, transition_rejected, access_denied, role_denied) | TESTED/PASSED (`test/claimLifecycle.test.ts`, `test/bola.test.ts`, `test/rbac.test.ts`). Phase 1 update: insurer transitions and denials also covered by `test/tenant.test.ts` STATE-001, STATE-003, TENANT-001/002/005/007; live counts in the "Audit rows for this run" block of `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` |
| AUD-02 | Audit rows cannot be updated/deleted | TESTED/PASSED (`test/audit.test.ts` "audit rows cannot be updated or deleted"). Residual: triggers droppable by a DB admin (open since Phase 0) |
| AUD-03 | No narratives, dev headers or tokens in audit rows | TESTED/PASSED (`test/audit.test.ts` "audit rows do not contain free-text claim narratives, headers or tokens" — Phase 1 update: also asserts no `Bearer` / `eyJ`) |
| AUD-04 | Every row has actor, action, outcome, request id (request ids are generated server-side in `src/index.ts`, never taken from a header) | TESTED/PASSED (`test/audit.test.ts` "every audit row records actor, action, outcome and request id") |
| AUD-05 | Secrets not in app logs | PARTIAL — Phase 1 update: rejected tokens are proven absent from `console.warn/error` (`test/auth.test.ts` "AUTH-013 server logs never contain the token"); other secrets NOT TESTED (manual review of `console.*` calls only) |
| AUD-06 | Phase 1 update — stage change and its audit row are written in ONE D1 batch; a stale precondition (0 rows updated) writes no `claim.stage_changed` row | TESTED/PASSED (`test/audit.test.ts` "a stage-change audit row is written only when the stage change applied (same transaction)") |
| AUD-07 | Phase 1 update — denials carry the actor's tenant (`actor_tenant_id`), and a denial row never names the target claim's tenant or owner | TESTED/PASSED (`test/tenant.test.ts` "AUDIT-001 every denial above produced an audit event with the actor tenant", "TENANT-001 …") |
| AUD-08 | Phase 1 update — no audit row for unauthenticated requests | TESTED/PASSED (`test/auth.test.ts` "AUTH-014 …") |

## Migration / data model (Phase 1 update)

`backend/migrations/0003_tenants.sql`: `tenants` table (`ins_discovery`, `ins_sanlam`, `ins_outsurance`, `ins_momentum`, `ins_oldmutual`), `policies.tenant_id` and `claims.tenant_id REFERENCES tenants(id)`, `audit_events.actor_tenant_id`, backfill by the five seed policy ids only, indexes.

| ID | Test | Method | Status |
|---|---|---|---|
| MIG-01 | Backfill re-assigns only the known seed policies by id and propagates to their claims; a legacy row that merely looks like a known insurer stays `NULL` (invisible to every insurer); rows that already had a tenant are untouched; exactly 6 `UPDATE` statements | `test/migration.test.ts` "re-assigns the known seed policies by id, propagates to their claims, and leaves every other row NULL" | TESTED/PASSED |
| MIG-02 | Backfill is idempotent (second run changes nothing) | `test/migration.test.ts` "the backfill is idempotent" | TESTED/PASSED |
| MIG-03 | `tenant_id` foreign key: inserting a policy with an unknown tenant fails | `test/migration.test.ts` "tenant_id references the tenants table" | TESTED/PASSED |
| MIG-04 | Per-environment wrangler config (`[env.production]`, separate `JWT_ISSUER`/`JWT_AUDIENCE`) | — NOT IMPLEMENTED | NOT TESTED |

## Test quality check

A mutation (forcing `allowed = true` in `loadAuthorizedClaim`) made 5 tests in `test/bola.test.ts` fail; the check was reverted.

Phase 1 update: no mutation check was re-run against the tenant guard (`isTenantInsurer`) or the JWT verifier; NOT TESTED. The live run in `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` is the independent confirmation that the automated results hold against `wrangler dev`.

## Known open items carried into Phase 2

Queue consumer does not fire under `wrangler dev` (re-observed in Phase 1: no consumer log lines); rate limiting approximate; `/profile`, `/client/*`, `/activities/*` remain demo stubs; `GET /profile/mandates/:tenantId/check` ignores its param; per-tenant claimant reference for insurer staff — DECISION REQUIRED; tenant admin functions NOT IMPLEMENTED.
