# EasyClaim Security Documentation

> **Token model (Phase 1).** Every `/api/v1/*` request must carry `Authorization: Bearer <JWT>`. The token is **verified, never merely decoded**, by `backend/src/security/actor.ts` (`resolveActor` → `hono/jwt` `verify(token, JWT_SECRET, { alg: 'HS256', iss: JWT_ISSUER, aud: JWT_AUDIENCE })` → `validateClaims`):
>
> - **Signature:** HS256 pinned; `alg: none`, HS512 and any other algorithm are rejected (`JwtAlgorithmMismatch` / `JwtHeaderInvalid`).
> - **Configuration is mandatory:** `JWT_SECRET` (>= 32 bytes; a *secret* binding — `backend/.dev.vars` locally, `wrangler secret put JWT_SECRET` when deployed), `JWT_ISSUER` and `JWT_AUDIENCE` (`wrangler.toml` `[vars]`). If any is missing, every request gets `401` and the misconfiguration is logged (fail closed).
> - **Claims (`validateClaims`):** `exp` and `iat` are required; `exp <= now` is rejected; remaining lifetime is capped by `MAX_TOKEN_TTL_SECONDS` (CUSTOMER 24 h; ASSESSOR / MANAGER / ADMIN 8 h); `sub` and `tenant_id` must match `ID_PATTERN`; `role` must be one of `ROLES`; `tenant_id` is **required** for ASSESSOR / MANAGER, **forbidden** for CUSTOMER and **optional** for ADMIN (DECISION REQUIRED: platform admin vs tenant admin).
> - **Failure handling:** the response is exactly `{"error":"unauthenticated"}` with `WWW-Authenticate: Bearer realm="easyclaim"`. Logs carry only the hono error class name or a fixed reason token, never the token. No audit row is written for unauthenticated requests (no pre-auth database writes).
> - **Removed:** the Phase 0 `X-Dev-Actor-*` header stub and `ALLOW_DEV_ACTOR_HEADERS` no longer exist in any code path (`test/actor.test.ts`, `test/auth.test.ts` AUTH-011 prove the headers are ignored).
> - **Local tokens:** `npm run setup:local` (`scripts/setup-dev-vars.mjs` creates `.dev.vars` with a random secret), then `npm run token -- --demo | --postman | --sub X --role Y [--tenant Z]` (`scripts/mint-token.mjs`; `iat` backdated 60 s; refuses claims the server would reject). The Postman collection `backend/EasyClaim.postman_collection.json` reads bearer tokens from the generated, gitignored `backend/postman/EasyClaim.local.postman_environment.json`; folders 0 / 5 / 6 / 7 are attack demonstrations.
> - **NOT IMPLEMENTED / PLANNED:** token revocation or a `jti` denylist, signing-key rotation, an external identity provider (`hono/jwt` `verifyWithJwks` is the documented path, not implemented), per-environment `wrangler.toml` `[env.production]`. The HS256 secret is shared: whoever holds it can mint a token for any role and tenant.

> Phase 0 history: until Phase 1 the API identified callers via a local-only `X-Dev-Actor-*` header stub (see [BACKEND_SECURITY_HANDOFF.md](BACKEND_SECURITY_HANDOFF.md) BACKEND-SEC-001 and [../phase-reports/PHASE_01_PRECHECK.md](../phase-reports/PHASE_01_PRECHECK.md)). That stub is gone.

## Current security posture (branch `cyber`, Phase 1 update)

| Area | Status | Where |
|---|---|---|
| Authentication | IMPLEMENTED, TESTED/PASSED — application-verified HS256 Bearer JWT (`iss`/`aud` pinned, `exp`+`iat` required, per-role max TTL, fail closed on missing config). Revocation, key rotation and IdP/JWKS: NOT IMPLEMENTED (PLANNED) | `backend/src/security/actor.ts` → `resolveActor`, `validateClaims`, `requireActor`; `test/auth.test.ts` (AUTH-001..014), `test/actor.test.ts` |
| Function-level authorization (RBAC) | IMPLEMENTED, TESTED/PASSED — role comes from the verified `role` claim; coarse `requireRole` runs before any resource lookup | `backend/src/security/rbac.ts`, `test/rbac.test.ts`, `test/tenant.test.ts` (RBAC-001/002) |
| Object-level authorization (claims, policies) | IMPLEMENTED, TESTED/PASSED — modes `read` / `owner-write` / `insurer`; denial and missing both `404 {"error":"not_found"}` + audit | `backend/src/security/claimAccess.ts` → `loadAuthorizedClaim`, `transitionClaim`; `test/bola.test.ts`, `test/tenant.test.ts` |
| Tenant/org scoping for insurer staff | IMPLEMENTED, TESTED/PASSED — `tenants` table; `policies.tenant_id` / `claims.tenant_id`; `isTenantInsurer()` = insurer role AND `actor.tenantId === claim.tenant_id` (non-null) AND stage ≠ Draft; `GET /claims` scoped per tenant / per owner. Evidence tenant isolation: BLOCKED (no evidence resource) | `backend/migrations/0003_tenants.sql`, `backend/src/security/claimAccess.ts`, `backend/src/endpoints/claims.ts`; `test/tenant.test.ts` (TENANT-001..007), `test/migration.test.ts` |
| Property-level authorization (mass assignment) | IMPLEMENTED, TESTED/PASSED — strict zod on every data-bearing route incl. `decideSchema` `{outcome}` and `listQuerySchema` `?limit` 1..50 | `backend/src/security/validation.ts` (strict zod), `test/massAssignment.test.ts`, `test/tenant.test.ts` |
| Claim state machine | IMPLEMENTED, TESTED/PASSED — all customer and insurer transitions reachable over HTTP; `transitionClaim` is the only stage-writing path (one D1 batch: conditional `UPDATE ... WHERE stage = ?` + audit `INSERT ... WHERE changes() = 1`; stale write → 409 `stale_state`). `Withdrawn` has no endpoint and `Expired` has no job (PLANNED) | `backend/src/security/claimStateMachine.ts`, `backend/src/security/claimAccess.ts`, `backend/src/endpoints/claimsInsurer.ts`; `test/stateMachine.test.ts`, `test/claimLifecycle.test.ts`, `test/tenant.test.ts` (STATE-001..006) |
| Audit trail (append-only) | IMPLEMENTED, TESTED/PASSED — now records `actor_tenant_id` and the server-generated `request_id`; stage changes and their audit row are written atomically. Triggers remain droppable by a DB admin (open) | `backend/src/security/audit.ts`, `migrations/0002_security.sql`, `migrations/0003_tenants.sql`, `test/audit.test.ts`, `test/tenant.test.ts` (AUDIT-001) |
| Rate limiting | IMPLEMENTED (approximate) — per IP before authentication and per actor (`actor:<role>:<id>`) after it, same `RATE_LIMITER` binding (100 req / 60 s per key) | `wrangler.toml` `[[ratelimits]]`, `src/index.ts`, `test/hardening.test.ts` |
| Security headers, CORS allowlist, body limit, generic errors | IMPLEMENTED, TESTED/PASSED — CORS `allowHeaders` now `Content-Type`, `Authorization` only | `src/index.ts`, `test/hardening.test.ts` |
| Queue message validation | IMPLEMENTED, TESTED/PASSED — consumer still not observed firing under `wrangler dev` (re-checked in Phase 1: no consumer log lines) | `src/endpoints/ocr.ts`, `test/queue.test.ts` |
| Evidence upload / storage | NOT IMPLEMENTED | only a queue event is sent; `TENANT-004` is an `it.todo` (BLOCKED) |
| OCR / AI | NOT IMPLEMENTED | `/ocr/process` is a stub |
| Decisions / payouts | PARTIAL — state transitions only. `POST /claims/:claimId/decide` (`{outcome: Approved\|Rejected}`, written to `claims.status`) and `POST /claims/:claimId/pay` (MANAGER-only via the state machine; requires status `Approved`, else 409 `not_approved`) exist in `backend/src/endpoints/claimsInsurer.ts`; `GET /claims/:claimId/decision` is read-only. No decision record (amount/reason), no payment execution, no separation of duties between decider and payer (DECISION REQUIRED), no appeal count limit (DECISION REQUIRED) | `backend/src/endpoints/claimsInsurer.ts`, `backend/src/endpoints/claims.ts`; `test/tenant.test.ts` |
| Dependency vulnerabilities | `npm audit`: 0 found | `backend/package-lock.json` |

Verification evidence (Phase 0): 85/85 tests pass across 9 files; a mutation check that disabled the ownership check made 5 BOLA tests fail; `npm run typecheck` passes.

Verification evidence (Phase 1 update): `npm test` — 12 files, 175 passed + 1 todo (`TENANT-004` evidence isolation, BLOCKED); new files `test/auth.test.ts`, `test/tenant.test.ts`, `test/migration.test.ts`; `test/actor.test.ts` migrated to JWT with every Phase 0 assertion kept. `npm run typecheck` clean; `npm audit` 0 vulnerabilities. Live evidence against `wrangler dev`: [../phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log](../phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log) — all ten ATTACK-P1 scenarios executed (forged / expired / tampered / `alg=none` / HS512 / over-TTL tokens → 401; cross-tenant read and transition → 404 identical to a missing claim; customer on insurer routes and assessor payout → 403; pay-before-decision and replayed pay → 409), plus a full Submitted → Paid path with the right tenant and roles, and the audit rows counted per action / role / tenant.

Open decisions (DECISION REQUIRED): ADMIN scope (platform vs tenant admin; `tenant_id` currently optional in ADMIN tokens and never used), separation of duties for decide vs pay, appeal count limit, per-tenant claimant reference (insurer lists omit `user_id`).

## Running the security tests

```bash
cd backend
npm install
npm test          # vitest + @cloudflare/vitest-plugin (real workerd + D1, fully local)
npm run typecheck
npm audit
```

Tests apply `migrations/` and `seed_sa_data.sql` to an isolated D1 per test file; they do not need `wrangler dev` running. Tests mint real HS256 tokens through `test/helpers.ts` (`mintToken`, `call({ as })`) with the secret from `vitest.config.mts` / `.dev.vars`.

To call the API locally (Phase 1 update):

```bash
cd backend
npm run setup:local            # creates .dev.vars with a random JWT_SECRET (never overwrites)
npm run dev                    # wrangler dev; every /api/v1/* request needs a bearer token
npm run token -- --demo        # prints one token per demo actor
npm run token -- --postman     # writes postman/EasyClaim.local.postman_environment.json (gitignored)
npm run token -- --sub user123 --role CUSTOMER
npm run token -- --sub assessor_a1 --role ASSESSOR --tenant ins_discovery
```

The live attack script used for the Phase 1 evidence is [../phase-reports/evidence/live-attacks.sh](../phase-reports/evidence/live-attacks.sh).

## Document index

| Document | Purpose |
|---|---|
| [../BACKEND_INVENTORY.md](../BACKEND_INVENTORY.md) | Verified repository inventory and endpoint table |
| [../architecture/BACKEND_ARCHITECTURE.md](../architecture/BACKEND_ARCHITECTURE.md) | Runtime architecture, request pipeline, data model |
| [SECURITY_REQUIREMENTS.md](SECURITY_REQUIREMENTS.md) | OWASP API Top 10 2023 / ASVS / SSDF mapped to EasyClaim |
| [THREAT_MODEL.md](THREAT_MODEL.md) | Assets, actors, trust boundaries, threats |
| [RBAC_MATRIX.md](RBAC_MATRIX.md) | Role × action permissions and ownership rules |
| [API_SECURITY_MATRIX.md](API_SECURITY_MATRIX.md) | Per-endpoint auth, role, object checks, risks |
| [CLAIM_STATE_SECURITY.md](CLAIM_STATE_SECURITY.md) | Claim lifecycle and transition rules |
| [EVIDENCE_SECURITY.md](EVIDENCE_SECURITY.md) | Evidence upload requirements (not implemented) |
| [DECISION_SECURITY.md](DECISION_SECURITY.md) | Decision protection and decision record |
| [PAYOUT_SECURITY.md](PAYOUT_SECURITY.md) | Payout protections (not implemented) |
| [AUDIT_SECURITY.md](AUDIT_SECURITY.md) | Audit events vs app logs |
| [AI_SECURITY.md](AI_SECURITY.md) | OCR/AI trust boundaries |
| [SECURITY_TEST_PLAN.md](SECURITY_TEST_PLAN.md) | Every security test and its status |
| [ATTACK_SCENARIOS.md](ATTACK_SCENARIOS.md) | 12 attack scenarios with before/after results |
| [SECURITY_IMPLEMENTATION_PLAN.md](SECURITY_IMPLEMENTATION_PLAN.md) | P0 / P1 / P2 / Bonus roadmap |
| [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) | Pre-demo and pre-deploy checklist |
| [BACKEND_SECURITY_HANDOFF.md](BACKEND_SECURITY_HANDOFF.md) | Concrete requirements for the backend team |

### Phase reports (`docs/phase-reports/`)

| Document | Purpose |
|---|---|
| [../phase-reports/PHASE_01_PRECHECK.md](../phase-reports/PHASE_01_PRECHECK.md) | Phase 1 precheck: Phase 0 claims re-verified against the repository; discrepancies D1–D3 |
| [../phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log](../phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log) | Phase 1 live evidence captured against `wrangler dev` (ATTACK-P1-001..012, happy path, audit counts) |
| [../phase-reports/evidence/live-attacks.sh](../phase-reports/evidence/live-attacks.sh) | Script that produced the live evidence log |
