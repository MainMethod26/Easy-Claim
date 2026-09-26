# EasyClaim Security Documentation

> **Token model (Phase 1).** Every `/api/v1/*` request must carry `Authorization: Bearer <JWT>`. The token is **verified, never merely decoded**, by `src/security/actor.ts` (`resolveActor` → `hono/jwt` `verify(token, JWT_SECRET, { alg: 'HS256', iss: JWT_ISSUER, aud: JWT_AUDIENCE })` → `validateClaims`):
>
> - **Signature:** HS256 pinned; `alg: none`, HS512 and any other algorithm are rejected (`JwtAlgorithmMismatch` / `JwtHeaderInvalid`).
> - **Configuration is mandatory:** `JWT_SECRET` (>= 32 bytes; a *secret* binding — `.dev.vars` locally, `wrangler secret put JWT_SECRET` when deployed), `JWT_ISSUER` and `JWT_AUDIENCE` (`wrangler.toml` `[vars]`). If any is missing, every request gets `401` and the misconfiguration is logged (fail closed).
> - **Claims (`validateClaims`):** `exp` and `iat` are required; `exp <= now` is rejected; remaining lifetime is capped by `MAX_TOKEN_TTL_SECONDS` (CUSTOMER 24 h; ASSESSOR / MANAGER / ADMIN 8 h); `sub` and `tenant_id` must match `ID_PATTERN`; `role` must be one of `ROLES`; `tenant_id` is **required** for ASSESSOR / MANAGER, **forbidden** for CUSTOMER and **optional** for ADMIN (DECISION REQUIRED: platform admin vs tenant admin).
> - **Failure handling:** the response is exactly `{"error":"unauthenticated"}` with `WWW-Authenticate: Bearer realm="easyclaim"`. Logs carry only the hono error class name or a fixed reason token, never the token. No audit row is written for unauthenticated requests (no pre-auth database writes).
> - **Removed:** the Phase 0 `X-Dev-Actor-*` header stub and `ALLOW_DEV_ACTOR_HEADERS` no longer exist in any code path (`test/actor.test.ts`, `test/auth.test.ts` AUTH-011 prove the headers are ignored).
> - **Local tokens:** `npm run setup:local` (`scripts/setup-dev-vars.mjs` creates `.dev.vars` with a random secret), then `npm run token -- --demo | --postman | --sub X --role Y [--tenant Z]` (`scripts/mint-token.mjs`; `iat` backdated 60 s; refuses claims the server would reject). The Postman collection `EasyClaim.postman_collection.json` reads bearer tokens from the generated, gitignored `postman/EasyClaim.local.postman_environment.json`; folders 0 / 5 / 6 / 7 are attack demonstrations.
> - **NOT IMPLEMENTED / PLANNED:** token revocation or a `jti` denylist, signing-key rotation, an external identity provider (`hono/jwt` `verifyWithJwks` is the documented path, not implemented), per-environment `wrangler.toml` `[env.production]`. The HS256 secret is shared: whoever holds it can mint a token for any role and tenant.

> Phase 0 history: until Phase 1 the API identified callers via a local-only `X-Dev-Actor-*` header stub (see [BACKEND_SECURITY_HANDOFF.md](BACKEND_SECURITY_HANDOFF.md) BACKEND-SEC-001 and [../phase-reports/PHASE_01_PRECHECK.md](../phase-reports/PHASE_01_PRECHECK.md)). That stub is gone.

## Current security posture (branch `cyber`, Phase 1 update)

| Area | Status | Where |
|---|---|---|
| Authentication | IMPLEMENTED, TESTED/PASSED — application-verified HS256 Bearer JWT (`iss`/`aud` pinned, `exp`+`iat` required, per-role max TTL, fail closed on missing config). Revocation, key rotation and IdP/JWKS: NOT IMPLEMENTED (PLANNED) | `src/security/actor.ts` → `resolveActor`, `validateClaims`, `requireActor`; `test/auth.test.ts` (AUTH-001..014), `test/actor.test.ts` |
| Function-level authorization (RBAC) | IMPLEMENTED, TESTED/PASSED — role comes from the verified `role` claim; coarse `requireRole` runs before any resource lookup | `src/security/rbac.ts`, `test/rbac.test.ts`, `test/tenant.test.ts` (RBAC-001/002) |
| Object-level authorization (claims, policies) | IMPLEMENTED, TESTED/PASSED — modes `read` / `owner-write` / `insurer`; denial and missing both `404 {"error":"not_found"}` + audit | `src/security/claimAccess.ts` → `loadAuthorizedClaim`, `transitionClaim`; `test/bola.test.ts`, `test/tenant.test.ts` |
| Tenant/org scoping for insurer staff | IMPLEMENTED, TESTED/PASSED — `tenants` table; `policies.tenant_id` / `claims.tenant_id`; `isTenantInsurer()` = insurer role AND `actor.tenantId === claim.tenant_id` (non-null) AND stage ≠ Draft; `GET /claims` scoped per tenant / per owner. Evidence tenant isolation: IMPLEMENTED, TESTED/PASSED (Phase 2) | `migrations/0003_tenants.sql`, `src/security/claimAccess.ts`, `src/endpoints/claims.ts`; `test/tenant.test.ts` (TENANT-001..007), `test/migration.test.ts`, `test/evidence.test.ts` |
| Property-level authorization (mass assignment) | IMPLEMENTED, TESTED/PASSED — strict zod on every data-bearing route incl. `decideSchema` `{outcome}` and `listQuerySchema` `?limit` 1..50 | `src/security/validation.ts` (strict zod), `test/massAssignment.test.ts`, `test/tenant.test.ts` |
| Claim state machine | IMPLEMENTED, TESTED/PASSED — all customer and insurer transitions reachable over HTTP; `transitionClaim` is the only stage-writing path (one D1 batch: conditional `UPDATE ... WHERE stage = ?` + audit `INSERT ... WHERE changes() = 1`; stale write → 409 `stale_state`). `Withdrawn` has no endpoint and `Expired` has no job (PLANNED) | `src/security/claimStateMachine.ts`, `src/security/claimAccess.ts`, `src/endpoints/claimsInsurer.ts`; `test/stateMachine.test.ts`, `test/claimLifecycle.test.ts`, `test/tenant.test.ts` (STATE-001..006) |
| Audit trail (append-only) | IMPLEMENTED, TESTED/PASSED — now records `actor_tenant_id` and the server-generated `request_id`; stage changes and their audit row are written atomically. Triggers remain droppable by a DB admin (open) | `src/security/audit.ts`, `migrations/0002_security.sql`, `migrations/0003_tenants.sql`, `test/audit.test.ts`, `test/tenant.test.ts` (AUDIT-001) |
| Rate limiting | IMPLEMENTED (approximate) — per IP before authentication and per actor (`actor:<role>:<id>`) after it, same `RATE_LIMITER` binding (100 req / 60 s per key) | `wrangler.toml` `[[ratelimits]]`, `src/index.ts`, `test/hardening.test.ts` |
| Security headers, CORS allowlist, body limit, generic errors | IMPLEMENTED, TESTED/PASSED — CORS `allowHeaders` now `Content-Type`, `Authorization` only | `src/index.ts`, `test/hardening.test.ts` |
| Queue message validation | IMPLEMENTED, TESTED/PASSED — consumer still not observed firing under `wrangler dev` (re-checked in Phase 1: no consumer log lines) | `src/endpoints/ocr.ts`, `test/queue.test.ts` |
| Evidence upload / storage | IMPLEMENTED, TESTED/PASSED (Phase 2) — private R2 storage, allowlist + magic-byte validation, backend SHA-256 with `VALID`/`TAMPERED` verification, tenant/ownership enforced | `src/endpoints/evidence.ts`, `src/security/evidence.ts`, `migrations/0004_evidence_security.sql`; `test/evidence.test.ts` |
| OCR / AI | NOT IMPLEMENTED | `/ocr/process` is a stub |
| Decisions / payouts | PARTIAL — state transitions only. `POST /claims/:claimId/decide` (`{outcome: Approved\|Rejected}`, written to `claims.status`) and `POST /claims/:claimId/pay` (MANAGER-only via the state machine; requires status `Approved`, else 409 `not_approved`) exist in `src/endpoints/claimsInsurer.ts`; `GET /claims/:claimId/decision` is read-only. No decision record (amount/reason), no payment execution, no separation of duties between decider and payer (DECISION REQUIRED), no appeal count limit (DECISION REQUIRED) | `src/endpoints/claimsInsurer.ts`, `src/endpoints/claims.ts`; `test/tenant.test.ts` |
| Dependency vulnerabilities | `npm audit`: 0 found | `package-lock.json` |

Verification evidence (Phase 0): 85/85 tests pass across 9 files; a mutation check that disabled the ownership check made 5 BOLA tests fail; `npm run typecheck` passes.

Verification evidence (Phase 1 update): `npm test` — 12 files, 183 passed + 1 todo (184; `TENANT-004` evidence isolation, BLOCKED), re-run 2026-09-26 at commit `cb2588a` while editing this page. Earlier Phase 1 material cites 175 + 1 todo from a run before the final test edits; [../phase-reports/PHASE_01_TENANT_MODEL.md](../phase-reports/PHASE_01_TENANT_MODEL.md) records both runs. New files `test/auth.test.ts`, `test/tenant.test.ts`, `test/migration.test.ts`; `test/actor.test.ts` migrated to JWT with every Phase 0 assertion kept. `npm run typecheck` clean; `npm audit` 0 vulnerabilities. Live evidence against `wrangler dev`: [../phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log](../phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log) — ATTACK-P1-001 through 012 executed, with the 004b / 004c / 004d variants (forged / expired / tampered / `alg=none` / HS512 / over-TTL tokens → 401; cross-tenant read and transition → 404 identical to a missing claim; customer on insurer routes and assessor payout → 403; pay-before-decision and replayed pay → 409), plus a full Submitted → Paid path with the right tenant and roles, and the audit rows counted per action / role / tenant.

Verification evidence (Phase 2 update): `test/evidence.test.ts` 15/15 passed; all 13 test files (198 tests total) pass
individually; `npm run typecheck` clean. See [../phase-reports/PHASE_02_REPORT.md](../phase-reports/PHASE_02_REPORT.md).

Open decisions (DECISION REQUIRED): ADMIN scope (platform vs tenant admin; `tenant_id` is currently optional in ADMIN tokens and is not used in any authorization decision — it is only recorded in `audit_events.actor_tenant_id`), separation of duties for decide vs pay, appeal count limit, per-tenant claimant reference (insurer lists omit `user_id`).

## Running the security tests

```bash
npm install
npm test          # vitest + @cloudflare/vitest-plugin (real workerd + D1, fully local)
npm run typecheck
npm audit
```

Tests apply `migrations/` and `seed_sa_data.sql` to an isolated D1 per test file; they do not need `wrangler dev` running. Tests mint real HS256 tokens through `test/helpers.ts` (`mintToken`, `call({ as })`) with `env.JWT_SECRET`; `vitest.config.mts` sets a fresh random `JWT_SECRET` per run plus `JWT_ISSUER` `easyclaim-test` / `JWT_AUDIENCE` `easyclaim-api` as test bindings (the plugin also reports loading `.dev.vars`, which locally holds only `JWT_SECRET` and `ALLOWED_ORIGINS`).

To call the API locally (Phase 1 update):

```bash
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
| [EVIDENCE_SECURITY.md](EVIDENCE_SECURITY.md) | Evidence upload, storage and integrity (implemented, Phase 2) |
| [DECISION_SECURITY.md](DECISION_SECURITY.md) | Decision protection and decision record (`POST /claims/:claimId/decide` is a state transition only; decision record NOT IMPLEMENTED) |
| [PAYOUT_SECURITY.md](PAYOUT_SECURITY.md) | Payout protections (`POST /claims/:claimId/pay` is a state transition only; payment execution NOT IMPLEMENTED) |
| [AUDIT_SECURITY.md](AUDIT_SECURITY.md) | Audit events vs app logs |
| [AI_SECURITY.md](AI_SECURITY.md) | OCR/AI trust boundaries |
| [SECURITY_TEST_PLAN.md](SECURITY_TEST_PLAN.md) | Every security test and its status |
| [ATTACK_SCENARIOS.md](ATTACK_SCENARIOS.md) | 12 Phase 0 attack scenarios with before/after results, plus the Phase 1 token / tenant / role attacks (ATTACK-P1-001..012) |
| [SECURITY_IMPLEMENTATION_PLAN.md](SECURITY_IMPLEMENTATION_PLAN.md) | P0 / P1 / P2 / Bonus roadmap |
| [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) | Pre-demo and pre-deploy checklist |
| [BACKEND_SECURITY_HANDOFF.md](BACKEND_SECURITY_HANDOFF.md) | Concrete requirements for the backend team |

### Phase reports (`docs/phase-reports/`)

| Document | Purpose |
|---|---|
| [../phase-reports/PHASE_01_PRECHECK.md](../phase-reports/PHASE_01_PRECHECK.md) | Phase 1 precheck: Phase 0 claims re-verified against the repository; discrepancies D1–D3 |
| [../phase-reports/PHASE_00_TO_PHASE_01.md](../phase-reports/PHASE_00_TO_PHASE_01.md) | Traceable history: what Phase 0 delivered, the seams and open items Phase 1 inherited, precheck facts that shaped the design |
| [../phase-reports/PHASE_01_REPORT.md](../phase-reports/PHASE_01_REPORT.md) | Phase 1 report: objective, starting state, what changed, authentication architecture, actor model |
| [../phase-reports/PHASE_01_AUTH_FLOW.md](../phase-reports/PHASE_01_AUTH_FLOW.md) | Authentication and authorization flow: the request chain for `POST /claims/:claimId/verify`, `resolveActor` / `validateClaims` decision points (exact 401 causes), token claims |
| [../phase-reports/PHASE_01_SECURITY_FLOW.md](../phase-reports/PHASE_01_SECURITY_FLOW.md) | Per-request security flow in code order (flowchart), why the coarse role gate runs before the claim lookup, `loadAuthorizedClaim` decision |
| [../phase-reports/PHASE_01_TENANT_MODEL.md](../phase-reports/PHASE_01_TENANT_MODEL.md) | Tenant model: what a tenant is, who carries `tenant_id`, demo topology and the forbidden cross-tenant path, how the boundary is enforced; records the 175 → 183 test-count change |
| [../phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log](../phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log) | Phase 1 live evidence captured against `wrangler dev` (ATTACK-P1-001..012, happy path, audit counts) |
| [../phase-reports/evidence/live-attacks.sh](../phase-reports/evidence/live-attacks.sh) | Script that produced the live evidence log |
| [../phase-reports/PHASE_02_PRECHECK.md](../phase-reports/PHASE_02_PRECHECK.md) | Phase 2 precheck: evidence functionality and gaps verified against the repository before implementation |
| [../phase-reports/PHASE_02_REPORT.md](../phase-reports/PHASE_02_REPORT.md) | Phase 2 report: evidence security + integrity implementation, flow, tests, limitations |
