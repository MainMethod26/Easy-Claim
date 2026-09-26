# EasyClaim Phase 1 Report

Date: 2026-09-26 · Branch: `cyber` · Base commit: `1468897` (Phase 0) · Phase 1 changes: **uncommitted working tree** (see §21)

Status vocabulary: IMPLEMENTED · PARTIAL · NOT IMPLEMENTED · PLANNED · BLOCKED · TESTED/PASSED · NOT TESTED · DECISION REQUIRED.
Every statement below points at code, a test, or the evidence log.

## 1. Objective

Convert the backend from "security controls behind a spoofable development actor" into "security controls operating on a
verified authenticated actor and a tenant boundary": User → Authentication → Actor → Role → Tenant → Authorization →
Claim access → Claim state transition. Out of scope and untouched: OCR/AI, evidence storage, payout execution, quantum work, frontend.

## 2. Starting State

Verified in `PHASE_01_PRECHECK.md` (171 checks; repository matched the Phase 0 report; 3 documentation-only discrepancies):
Cloudflare Worker + Hono 4.13.9 + D1 + Queue; 24 endpoints; 85 tests passing; typecheck and `npm audit` clean;
`resolveActor()` honoured `X-Dev-Actor-Id/Role` headers when `ALLOW_DEV_ACTOR_HEADERS=true`; no tenant concept anywhere;
insurer transitions existed only in the state machine, not over HTTP.

## 3. What We Changed

| Area | Change | Where |
|---|---|---|
| Authentication | Bearer JWT verified with `hono/jwt` (HS256 pinned; `iss`, `aud`, `exp`, `iat` required; TTL cap; fail-closed config; no token in logs); dev header stub deleted | `backend/src/security/actor.ts`, `backend/src/index.ts` |
| Actor model | `Actor { id, role, tenantId }`; tenant required for ASSESSOR/MANAGER, forbidden for CUSTOMER, optional for ADMIN | `backend/src/types.ts` |
| Tenants | `tenants` table, `policies.tenant_id`, `claims.tenant_id`, `audit_events.actor_tenant_id`; seed updated; safe backfill by seed id | `backend/migrations/0003_tenants.sql`, `backend/seed_sa_data.sql` |
| Authorization | `loadAuthorizedClaim` gains `'insurer'` mode and the tenant boundary; drafts and NULL-tenant claims hidden from insurers; `transitionClaim` re-asserts owner/tenant and writes state change + audit in one D1 batch | `backend/src/security/claimAccess.ts`, `audit.ts` |
| Insurer operations | `POST /claims/:id/verify`, `/screen`, `/review`, `/request-info`, `/decide`, `/pay` through the state machine; `GET /claims` scoped list | `backend/src/endpoints/claimsInsurer.ts`, `claims.ts` |
| Hardening | server-generated request ids in audit rows; per-actor rate limit after auth; screening write repeats the stage precondition in SQL; timeline honours side states | `backend/src/index.ts`, `claims.ts` |
| Local tooling | `npm run setup:local` (random secret into `.dev.vars`), `npm run token` (mint demo tokens / Postman environment) | `backend/scripts/*.mjs`, `backend/package.json` |
| Postman | bearer-token collection with 8 folders (unauthenticated, customer, tenant A assessor/manager, tenant B, cross-tenant attack, role attacks, token attacks); tokens come from a generated, gitignored environment file | `backend/EasyClaim.postman_collection.json` |
| Tests | 85 → 183 tests (+1 todo) in 12 files | `backend/test/` |

## 4. Authentication Architecture

Decision: **Option B now, Option A later.** The backend verifies HS256 tokens itself (`JWT_SECRET` secret binding) because no
identity provider exists in the hackathon; the same `resolveActor()` seam switches to `hono/jwt` `verifyWithJwks` for an
external IdP without touching authorization code. Details and diagrams: `PHASE_01_AUTH_FLOW.md`.

Contract (`backend/src/security/actor.ts`): `Authorization: Bearer <JWT>` (scheme case-insensitive, token must be three
base64url segments). `verify(token, JWT_SECRET, { alg: 'HS256', iss: JWT_ISSUER, aud: JWT_AUDIENCE })`; then
`validateClaims()`: `exp` and `iat` required, `exp` in the future and at most 24 h (CUSTOMER) / 8 h (staff) away,
`sub` and `tenant_id` match `^[A-Za-z0-9_-]{1,64}$`, `role ∈ {CUSTOMER, ASSESSOR, MANAGER, ADMIN}`. Any failure → `401
{"error":"unauthenticated"}` + `WWW-Authenticate: Bearer`; only the hono error class name or a fixed reason token is logged;
no audit row is written for unauthenticated requests. Missing/short `JWT_SECRET` (< 32 bytes) or missing `JWT_ISSUER` /
`JWT_AUDIENCE` refuses every request and logs a misconfiguration line.

Dev actor: **removed** (no code path reads `X-Dev-Actor-*`; `ALLOW_DEV_ACTOR_HEADERS` is gone from bindings, config and tests
except as a proven-ignored input in `test/actor.test.ts` / `test/auth.test.ts` AUTH-011).

## 5. Actor Model

| Role | Meaning | `tenantId` | Claim access |
|---|---|---|---|
| CUSTOMER | Platform-level policyholder; seed data shows one customer holding policies with three insurers | must be absent | own claims (`claims.user_id`) |
| ASSESSOR | Insurer staff who verify/screen/review/request info/decide | required | claims of own tenant, submitted or later |
| MANAGER | Insurer staff; additionally pays and re-reviews appeals | required | as ASSESSOR + `Decision → Paid`, `Appeal → Review` |
| ADMIN | Reserved for configuration/user administration | optional, ignored | none |

DECISION REQUIRED: ADMIN scope (platform vs tenant); whether ASSESSORs may decide (state machine allows it today).

## 6. Tenant Isolation Model

Tenant = insurer organisation (`tenants` table: `ins_discovery`, `ins_sanlam`, `ins_outsurance`, `ins_momentum`, `ins_oldmutual`).
`claims.tenant_id` is copied from the policy at `POST /claims/initiate` and never taken from the client; a policy without a
tenant cannot start a claim (422, audited). Insurer access = `INSURER_ROLES.includes(role) && actor.tenantId === claim.tenant_id
(non-null) && stage !== 'Draft'` (`isTenantInsurer()`). Cross-tenant, non-existent, draft and NULL-tenant cases all answer
`404 {"error":"not_found"}` and write `authz.claim_access_denied` with `reason ∈ {cross_tenant, missing, draft, tenant_unset, …}`
naming only the actor's context. Diagram and forbidden path: `PHASE_01_TENANT_MODEL.md`.

## 7. Authorization Flow

Order on every resource route (`PHASE_01_SECURITY_FLOW.md`):
1. `requireActor` — verified token → `Actor` (401)
2. coarse `requireRole` — resource-independent, so it cannot leak cross-tenant information (403, `authz.role_denied`)
3. strict zod validation of params/body/query (400)
4. `loadAuthorizedClaim` — load → tenant boundary → ownership → mode (404, `authz.claim_access_denied`)
5. `transitionClaim` — owner/tenant guard (403), state-machine edge and per-transition role (409/403, `claim.transition_rejected`)
6. one D1 batch: `UPDATE … WHERE id = ? AND stage = ?` + `INSERT INTO audit_events … WHERE changes() = 1` (409 `stale_state` if 0 rows, audited)

## 8. Claim Security Changes

- All state-machine transitions are now reachable over HTTP with the intended roles (verify/screen/review/request-info by ASSESSOR or MANAGER, decide by ASSESSOR or MANAGER, pay by MANAGER only and only when `status = 'Approved'`).
- `/decide` writes the outcome as `claims.status` in the same statement as the stage change; `/pay` is a state transition only (no money moves).
- Customers' `PATCH /screening` write now carries `AND stage IN ('Draft','Info Needed')` in SQL.
- `GET /claims` returns own claims to customers and tenant claims (no drafts, no `user_id`) to insurers; ADMIN gets 403; `limit` is bounded to 50.
- Timeline marks stages completed from the audit trail, so side states (Info Needed, Appeal) no longer blank the history.

## 9. Files Created

`backend/src/endpoints/claimsInsurer.ts` · `backend/migrations/0003_tenants.sql` · `backend/scripts/mint-token.mjs` ·
`backend/scripts/setup-dev-vars.mjs` · `backend/test/auth.test.ts` · `backend/test/tenant.test.ts` · `backend/test/migration.test.ts` ·
`docs/phase-reports/PHASE_01_PRECHECK.md` · `PHASE_01_REPORT.md` (this) · `PHASE_01_AUTH_FLOW.md` · `PHASE_01_TENANT_MODEL.md` ·
`PHASE_01_SECURITY_FLOW.md` · `PHASE_00_TO_PHASE_01.md` · `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` · `evidence/live-attacks.sh`

## 10. Files Modified

Code: `backend/src/security/actor.ts`, `audit.ts`, `claimAccess.ts`, `validation.ts`; `backend/src/types.ts`; `backend/src/index.ts`;
`backend/src/endpoints/claims.ts`; `backend/seed_sa_data.sql`; `backend/wrangler.toml`; `backend/.dev.vars.example`; `backend/.gitignore`;
`.gitignore`; `backend/package.json`; `backend/vitest.config.mts`; `backend/EasyClaim.postman_collection.json`;
tests `backend/test/actor.test.ts`, `audit.test.ts`, `hardening.test.ts`, `massAssignment.test.ts`, `helpers.ts`.
Docs: `README.md`, `docs/BACKEND_INVENTORY.md`, `docs/architecture/BACKEND_ARCHITECTURE.md`, `docs/security/README.md`, `RBAC_MATRIX.md`,
`API_SECURITY_MATRIX.md`, `THREAT_MODEL.md`, `CLAIM_STATE_SECURITY.md`, `AUDIT_SECURITY.md`, `DECISION_SECURITY.md`, `PAYOUT_SECURITY.md`,
`SECURITY_CHECKLIST.md`, `SECURITY_TEST_PLAN.md`, `ATTACK_SCENARIOS.md`, `BACKEND_SECURITY_HANDOFF.md`, `SECURITY_IMPLEMENTATION_PLAN.md`,
`SECURITY_REQUIREMENTS.md`. (Exact list: `git status --short`, §21.)

## 11. Database Changes

Migration `0003_tenants.sql` (applied locally with `npm run db:migrate:local`, and in every test run):
`tenants(id, name)` with the five demo insurers; `ALTER TABLE policies ADD COLUMN tenant_id TEXT REFERENCES tenants(id)`;
`ALTER TABLE claims ADD COLUMN tenant_id TEXT REFERENCES tenants(id)`; `ALTER TABLE audit_events ADD COLUMN actor_tenant_id TEXT`;
backfill of the five seed policies **by id only** (never by name) and of claims from their policy; indexes on both `tenant_id` columns.
No table was redesigned; `audit_events` triggers unchanged.

## 12. Tests Added

| File | IDs | What it proves |
|---|---|---|
| `test/auth.test.ts` (new) | AUTH-001…014 | no/malformed/expired/forged/tampered/`alg=none`/HS512/over-TTL tokens → 401; valid → 200; issuer/audience/iat/nbf rules; misconfiguration fails closed; dev headers never bypass; logs never contain the token; no audit rows for 401 |
| `test/actor.test.ts` (migrated) | — | all Phase 0 assertions kept (fail closed, unknown role, malformed id, every route requires an actor) now against JWT; retired headers proven ignored; `actorFromClaims` matrix incl. TTL caps |
| `test/tenant.test.ts` (new) | TENANT-001…007, STATE-001…006, RBAC-001/002, AUDIT-001 | cross-tenant read/transition → 404 + audited; NULL-tenant and draft fail closed; scoped lists; full Submitted→Paid path with roles; wrong tenant / insufficient role / illegal edge; appeal and info-request round trips |
| `test/migration.test.ts` (new) | — | backfill assigns only seed ids, leaves look-alikes NULL, is idempotent; FK enforced |
| `test/audit.test.ts` (extended) | — | concurrent submits: one 200 / one 409 / one `stage_changed` row (real path); `changes()`-gated INSERT mechanism; request ids server-generated |
| `test/hardening.test.ts` (extended) | — | per-IP then per-actor limiter keys; actor limiter denial → 429 |
| `test/massAssignment.test.ts` (extended) | — | `tenantId`/`tenant_id` rejected on screening and initiate; tenant derived from policy |

TENANT-004 (evidence resource isolation) is `it.todo` — BLOCKED: no evidence endpoint exists.

## 13. Tests Passed

```
cd backend
npm test          → Test Files 12 passed (12); Tests 183 passed | 1 todo (184)   (vitest 4.1.11, workerd + D1)
npm run typecheck → tsc --noEmit, exit 0
npm audit         → found 0 vulnerabilities
npm run db:migrate:local → 0003_tenants.sql ✅ (existing local DB backfilled; verified by query)
```
Phase 0 suites (bola, rbac, massAssignment, claimLifecycle, hardening, audit, queue, stateMachine) all pass unchanged in intent
(REGRESSION-001). Test-honesty review fixes applied: `alg=none` now reaches the verifier (proven via the logged `JwtHeaderInvalid`),
expiry test uses a fake clock instead of a wall-clock race, list/denial assertions are order-independent.

## 14. Attack Scenarios

Executed live against `wrangler dev` (`docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log`; script in `evidence/live-attacks.sh`)
and in the automated suite. PASS only where both the expected status and the expected side effect were observed.

| ID | Attack | Expected | Actual (live) | Test | Status |
|---|---|---|---|---|---|
| ATTACK-P1-001 | Forged JWT (other secret) | 401 | `401 unauthenticated` | AUTH-004 | PASS |
| ATTACK-P1-002 | Expired JWT | 401 | `401` | AUTH-003 | PASS |
| ATTACK-P1-003 | Wrong signature | 401 | `401` | AUTH-004 | PASS |
| ATTACK-P1-004 | Role escalation by editing claims (+ `alg=none`, HS512, 9 h staff token) | 401 | `401` for all four; `alg=none` logged as `JwtHeaderInvalid` | AUTH-004b/c/d, AUTH-006c | PASS |
| ATTACK-P1-005 | Tenant B assessor reads tenant A claim | 404, identical to missing claim, audited | `404 not_found` both; audit `cross_tenant` | TENANT-001/003 | PASS |
| ATTACK-P1-006 | Tenant B staff verify/decide tenant A claim | 404, stage unchanged | `404`, stage still Review | TENANT-002/002b, STATE-002 | PASS |
| ATTACK-P1-007 | Customer → insurer-only endpoints | 403, no claim data | `403 forbidden` ×3 | RBAC-001 | PASS |
| ATTACK-P1-008 | Assessor → manager-only pay | 403 | `403 forbidden` | STATE-003 | PASS |
| ATTACK-P1-009 | Token reuse after expiration | 200 then 401 | `200` then `401` 3 s later | AUTH-008 | PASS |
| ATTACK-P1-010 | Dev headers bypass | 401 / ignored | `401` without token; `403` with customer token (headers ignored) | AUTH-011 | PASS |
| supplementary | IDOR regression, ADMIN access, tenant-scoped lists, Submitted→Paid happy path incl. replay and pay-before-decision | — | as designed (see log) | bola/rbac/tenant suites | PASS |
| evidence tampering, malicious upload, payout diversion, config tampering | — | — | — | — | BLOCKED (features not implemented) |

## 15. Security Improvements

Identity now comes from a verified credential, not a header; every insurer action is confined to the actor's tenant; all
claim transitions are reachable only through one audited, replay-safe path; audit rows can no longer exist without their state
change and cannot be correlated by attacker-chosen request ids; one credential cannot exhaust the API from many addresses;
tokens have bounded lifetimes; the signing secret never enters the repository or Postman.

## 16. Remaining Risks

- Shared-secret HS256: anyone with `JWT_SECRET` can mint any actor; no revocation, no key rotation, no IdP (PLANNED, BACKEND-SEC-019).
- One global `wrangler.toml` `[vars]` block: `JWT_ISSUER = easyclaim-dev` and the placeholder `database_id` would ship to any deploy (BACKEND-SEC-018).
- Separation of duties: the same MANAGER may decide and pay; the decider may re-review an appeal (DECISION REQUIRED, 015).
- Appeal cycle unbounded (016); `claims.status` keeps the last decision while a claim is in Appeal (`GET /decision` masks it, `GET /claims` does not).
- ADMIN scope undefined (020); assessors may decide (005).
- Evidence, OCR, decision records, payment execution, configuration: NOT IMPLEMENTED; evidence tenant isolation BLOCKED.
- `audit_events` triggers can be dropped by anyone with D1 admin rights; no retention/export.
- Rate limiting is approximate and per-location by design; the IP key is `unknown` when `cf-connecting-ip` is absent (local dev).
- Clock skew: `iat` in the future is rejected with zero leeway (mint script backdates 60 s).
- Claim rules in `scripts/mint-token.mjs` are a hand-maintained copy of `actor.ts`.
- Queue consumer fired in this run (§17), contradicting the Phase 0 observation; treat as intermittent until understood.

## 17. Backend Team Handoff

`docs/security/BACKEND_SECURITY_HANDOFF.md` — items 001/002/003/012/013 marked IMPLEMENTED with acceptance evidence; new items
015–020 (separation of duties, appeal limit, claimant reference, per-environment config, IdP/rotation/revocation, ADMIN scope).
Observation for 011: `OCR Service processing claim: claim_0e19…` appeared in the dev-server log after the live submit, so the
consumer does run under `wrangler dev` at least sometimes.

## 18. What Is Still Not Implemented

External identity provider / JWKS; key rotation; revocation; per-environment configuration; decision records with reason/amount;
payment execution and destination handling; evidence upload/storage/hashing; OCR/AI; configuration management; tenant admin
functions; Withdrawn/Expired endpoints or jobs; CI; the frontend.

## 19. Demo Instructions

```bash
cd backend
npm install
npm run setup:local          # creates .dev.vars with a random JWT_SECRET (gitignored)
npm run db:migrate:local && npm run db:seed:local
npm run dev                  # http://127.0.0.1:8787
npm run token -- --postman   # writes postman/EasyClaim.local.postman_environment.json (gitignored)
```
Import `backend/EasyClaim.postman_collection.json` and the generated environment into Postman. Folders: 0 unauthenticated (401),
1 customer, 2 assessor tenant A, 3 manager tenant A, 4 assessor tenant B, 5 cross-tenant attack (404), 6 role attacks (403),
7 token attacks (401). Wizard: run "initiate" in folder 1, paste the returned id into the `claimId` variable, then screening →
submit → (folder 2) verify → screen → review → (folder 3) decide → pay. Command line: `TOKEN=$(npm run -s token -- --sub user123 --role CUSTOMER)`
then `curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8787/api/v1/claims`.

## 20. Verification Commands

```bash
cd backend && npm run typecheck && npm test && npm audit
npm run db:migrate:local
bash ../docs/phase-reports/evidence/live-attacks.sh     # against a running `npm run dev`
git -C .. diff --check
```

## 21. Git Commit / Branch Information

Branch `cyber` (tracking `origin/cyber`, PR #1 open for Phase 0). Phase 1 is **not committed and not pushed** — the working tree
holds the changes (see the final `git status` / `git diff --stat` in the delivery message). Recommended commit message when approved:

```
feat(security): add authenticated actor and tenant isolation
```
