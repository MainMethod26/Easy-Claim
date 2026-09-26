# Security Requirements

These requirements use **OWASP API Security Top 10 2023**, **OWASP ASVS 5.0** and **NIST SSDF (SP 800-218)** as *assessment and implementation references*. EasyClaim does **not** claim to comply with any of them.

Status values: IMPLEMENTED · PARTIAL · NOT IMPLEMENTED · PLANNED. Test values: a test file path (TESTED/PASSED as of the last run, 85/85) or NOT TESTED.

All paths are relative to `backend/`.

## OWASP API Security Top 10 2023

| Reference | Requirement | EasyClaim risk | Status | Location | Required change | Test | Priority |
|---|---|---|---|---|---|---|---|
| API1 BOLA | Every `:claimId` access checks the actor may access that claim | Customer A reads, edits or submits customer B's claim | IMPLEMENTED for claims. PARTIAL overall: insurer staff can read **all** claims because there is no org/tenant model | `src/security/claimAccess.ts` `loadAuthorizedClaim`; `src/endpoints/claims.ts` | Add an insurer org scope once the org model exists. Apply the same check to evidence, decision and payout IDs when they exist | `test/bola.test.ts` | P0 |
| API1 BOLA | Policy-scoped reads use the actor, not a constant | `my-covers` returned `user123` data to everyone | IMPLEMENTED | `src/endpoints/policy.ts` `/my-covers` | none | `test/bola.test.ts` | P0 |
| API1 BOLA | `/profile/mandates/:tenantId/check` | Stub that returns `{active:true}` for any tenantId | NOT IMPLEMENTED (stub) | `src/endpoints/identity.ts` | When real, scope it to the actor's own mandates | NOT TESTED | P1 |
| API2 Broken Authentication | Verified identity on every request | Phase 0: no identity provider, spoofable dev header stub. Phase 1: shared-secret HS256 (no revocation, no IdP yet) | IMPLEMENTED (Phase 1): app-verified bearer JWT, pinned `alg`, required `iss`/`aud`/`exp`/`iat`, TTL cap, fail-closed configuration; dev stub removed | `src/security/actor.ts` `resolveActor`, `validateClaims` | Backend team: IdP/JWKS + key rotation + revocation (BACKEND-SEC-019) | `test/auth.test.ts` AUTH-001…014, `test/actor.test.ts` TESTED/PASSED; live `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` | P0 |
| API3 BOPLA | Clients cannot set `stage`, `status`, `user_id`, `riskScore`, `decision`, `approvedBy` | Mass assignment to approve a claim or change its owner | IMPLEMENTED (strict zod schemas) | `src/security/validation.ts` | Keep all new schemas `.strict()` | `test/massAssignment.test.ts` | P0 |
| API3 BOPLA | Responses don't echo request bodies or leak other users' fields | `join-request` echoed the raw body | IMPLEMENTED | `src/endpoints/policy.ts` | Add response schemas for new endpoints | `test/massAssignment.test.ts` | P0 |
| API4 Resource consumption | Body size limit | Large JSON bodies waste CPU | IMPLEMENTED (64 KB) | `src/index.ts` `bodyLimit` | Evidence upload needs its own limit | `test/hardening.test.ts` | P0 |
| API4 Resource consumption | Rate limiting | Brute force and scraping | PARTIAL: per-IP only, approximate (100/60 s). Tested locally: 429 after about 100 requests | `src/index.ts`, `wrangler.toml` `[[ratelimits]]` | Add per-actor and per-endpoint limits for expensive operations (OCR, submit) | `test/hardening.test.ts` (429 path) | P0 |
| API4 Resource consumption | Pagination | None of the list endpoints paginate | NOT IMPLEMENTED | `src/endpoints/*` | Add `limit`/`cursor` with a max cap when lists become real | NOT TESTED | P1 |
| API5 BFLA | Role checks on privileged functions | A customer calls insurer OCR, or an insurer creates claims | IMPLEMENTED | `src/security/rbac.ts` `requireRole` | Guard every future insurer endpoint | `test/rbac.test.ts` | P0 |
| API6 Sensitive business flows | Claim workflow can't be skipped or replayed | Submitting twice; jumping to Paid | IMPLEMENTED (state machine + conditional UPDATE) | `src/security/claimStateMachine.ts`, `claimAccess.ts` `transitionClaim` | Add insurer transition endpoints that use `transitionClaim` | `test/stateMachine.test.ts`, `test/claimLifecycle.test.ts` | P0 |
| API6 Sensitive business flows | Payout, mandate cancel and join-request abuse | Payout diversion, mandate cancel for another user | NOT IMPLEMENTED (no payout exists; mandate cancel is a stub) | `src/endpoints/identity.ts` | See PAYOUT_SECURITY.md | NOT TESTED | P1 |
| API7 SSRF | No user-supplied URLs are fetched | Not reachable today | N/A (verified: no `fetch()` of client input) | — | Evidence-by-URL must never be accepted | NOT TESTED | P2 |
| API8 Misconfiguration | Security headers, strict CORS, generic errors | Stack traces, wildcard CORS | IMPLEMENTED | `src/index.ts` (`secureHeaders`, `cors`, `onError`, `notFound`) | Set `ALLOWED_ORIGINS` per environment | `test/hardening.test.ts` | P0 |
| API8 Misconfiguration | Authentication configuration cannot silently weaken | Phase 0 flag `ALLOW_DEV_ACTOR_HEADERS` removed in Phase 1. Remaining: `JWT_SECRET` must be a secret binding and `JWT_ISSUER`/`JWT_AUDIENCE` must differ per environment | PARTIAL: missing/short secret or missing issuer/audience → every request 401 (fail closed, `test/auth.test.ts` AUTH-009/010); no `[env.production]` block yet | `src/security/actor.ts`, `wrangler.toml`, `.dev.vars.example` | Per-environment config + `wrangler secret put --env` (BACKEND-SEC-018) | AUTH-009/010 TESTED/PASSED; deploy check NOT TESTED | P0 |
| API9 Inventory | Documented, versioned endpoint list | Undocumented stubs remain exposed | IMPLEMENTED (docs) | `docs/BACKEND_INVENTORY.md`, `docs/security/API_SECURITY_MATRIX.md` | Keep it updated per PR | n/a | P1 |
| API10 Unsafe third-party consumption | Queue messages and future OCR/AI output are untrusted | A malformed or injected message drives behaviour | IMPLEMENTED for the queue (zod validation, malformed messages are acked and dropped) | `src/endpoints/ocr.ts` `processQueueBatch` | Apply the same to OCR/AI output (AI_SECURITY.md) | `test/queue.test.ts` | P1 |

## OWASP ASVS 5.0 (chapter names used generically)

| Reference | Requirement | EasyClaim risk | Status | Location | Required change | Test | Priority |
|---|---|---|---|---|---|---|---|
| Encoding & sanitization | Parameterised SQL everywhere | SQL injection via IDs | IMPLEMENTED (all `prepare().bind()`) | `src/models/policyModel.ts`, `src/endpoints/claims.ts`, `src/security/*` | Never concatenate SQL | `test/actor.test.ts` (injection-shaped id rejected) | P0 |
| Validation & business logic | Allowlist validation on params and bodies | Path/ID tampering, future-dated incidents | IMPLEMENTED | `src/security/validation.ts` | Add schemas to every new route | `test/massAssignment.test.ts` | P0 |
| Web service / API | JSON-only errors, correct status codes | Information leakage | IMPLEMENTED | `src/index.ts` | — | `test/hardening.test.ts` | P1 |
| Authentication | Credentials verified server-side, tokens expire | No auth | NOT IMPLEMENTED | `src/security/actor.ts` | Backend team (BACKEND-SEC-001) | NOT TESTED | P0 |
| Authorization | Deny by default; object + function level | IDOR, BFLA | IMPLEMENTED (deny-by-default 401 on `/api/v1/*`) | `src/index.ts`, `rbac.ts`, `claimAccess.ts` | Tenant scoping | `test/bola.test.ts`, `test/rbac.test.ts` | P0 |
| Data protection | Minimise PII in responses and logs | `SELECT *` returns all policy columns | PARTIAL | `src/models/policyModel.ts` | Select explicit columns | NOT TESTED | P1 |
| Security logging & error handling | Audit sensitive actions; audit is tamper-resistant; no secrets in logs | Repudiation, silent abuse | IMPLEMENTED (insert-only `audit_events`, DB triggers block UPDATE/DELETE) | `src/security/audit.ts`, `migrations/0002_security.sql` | Add audit for future decision, payout and config actions | `test/audit.test.ts` | P0 |
| Files & resources | Upload validation | Malicious files | NOT IMPLEMENTED (no upload exists) | — | See EVIDENCE_SECURITY.md | NOT TESTED | P1 |

## NIST SSDF (SP 800-218)

| Practice | Requirement | Status | Location | Required change | Priority |
|---|---|---|---|---|---|
| PO.1 Define security requirements | Written requirements tied to code | IMPLEMENTED | `docs/security/` | Review each sprint | P0 |
| PO.5 Secure environments | Secrets outside the repo | IMPLEMENTED (`.dev.vars` gitignored; no secrets found in the repo) | `backend/.gitignore` | Use `wrangler secret put` for JWT keys | P0 |
| PS.1 Protect code | Branch protection and reviews | NOT IMPLEMENTED (repo setting) | GitHub | Require PR review on `main` | P1 |
| PW.4 Reuse vetted components | Use framework middleware rather than custom crypto/auth | IMPLEMENTED (Hono `secure-headers`/`cors`/`body-limit`, zod) | `src/index.ts` | — | P1 |
| PW.7/PW.8 Review and test code | Automated security tests | IMPLEMENTED (85 tests, 9 files) | `backend/test/` | Run in CI on every PR | P0 |
| RV.1 Identify vulnerabilities | Dependency scanning | PARTIAL (`npm audit`: 0 vulnerabilities, run manually) | `backend/package.json` | Add `npm audit` and Dependabot to CI | P1 |
| RV.2 Respond to vulnerabilities | Track and retest findings | IMPLEMENTED (docs) | `docs/security/ATTACK_SCENARIOS.md` | Retest per release | P1 |
