# Security Implementation Plan

Owner: **Cyber** = delivered on branch `cyber`; **Backend** = backend team.

## P0 — Must have

| Item | Status | Owner | Files |
|---|---|---|---|
| Authentication | NOT IMPLEMENTED | Backend | Replace `resolveActor()` in `backend/src/security/actor.ts`. Recommended: `hono/jwt` HS256 with pinned `alg`, `JWT_SECRET` via `wrangler secret put`, required `sub`/`role`/`exp`; or a managed IdP |
| Dev actor stub that fails closed | IMPLEMENTED | Cyber | `backend/src/security/actor.ts`, `.dev.vars.example` |
| RBAC (function-level) | IMPLEMENTED | Cyber | `backend/src/security/rbac.ts`; applied in `src/endpoints/*.ts` |
| Object-level authorization (claims, policies) | IMPLEMENTED | Cyber | `backend/src/security/claimAccess.ts`, `src/endpoints/claims.ts`, `src/endpoints/policy.ts` |
| Tenant/org scoping for insurer staff | NOT IMPLEMENTED (P0 gap) | Backend | add `organization_id` to users/policies/claims; extend `loadAuthorizedClaim()` |
| Property-level authorization | IMPLEMENTED | Cyber | `backend/src/security/validation.ts` |
| Secure claim state transitions | IMPLEMENTED (customer routes); insurer routes PLANNED | Cyber / Backend | `backend/src/security/claimStateMachine.ts`, `transitionClaim()` |
| Evidence access control | PARTIAL (ownership on evidence-ocr route; no files) | Cyber / Backend | `src/endpoints/claims.ts` |
| Evidence validation | NOT IMPLEMENTED (no upload) | Backend | see `EVIDENCE_SECURITY.md` |
| Input validation | IMPLEMENTED for all routes with bodies/params | Cyber | `validation.ts` |
| Secrets protection | IMPLEMENTED (`.dev.vars` gitignored; no secrets in repo) | Cyber | `backend/.gitignore` |
| Audit of sensitive actions | IMPLEMENTED for existing actions | Cyber | `backend/src/security/audit.ts`, `migrations/0002_security.sql` |
| Basic rate/resource limits | IMPLEMENTED (approximate per-IP rate, 64 KB body) | Cyber | `wrangler.toml`, `src/index.ts` |
| Security headers, CORS allowlist, generic errors | IMPLEMENTED | Cyber | `src/index.ts` |
| Security tests | IMPLEMENTED (85 tests) | Cyber | `backend/test/*.test.ts`, `vitest.config.mts` |

## P1 — Important

| Item | Status | Owner |
|---|---|---|
| Evidence hashing / tamper detection (SHA-256 into `evidence.sha256`) | PLANNED (table exists) | Backend |
| Payout protection (MANAGER-only, destination verification, idempotency) | PLANNED (state machine enforces MANAGER for Paid) | Backend |
| Step-up authentication for payout/mandate/banking changes | PLANNED | Backend |
| Configuration versioning + audit | PLANNED (no config exists) | Backend |
| Explainable screening signals | PLANNED | Backend |
| AI/OCR trust boundaries | PLANNED (documented in `AI_SECURITY.md`; queue validation IMPLEMENTED) | Backend |
| Dependency scanning in CI (`npm audit`) | PARTIAL (run manually: 0 vulns) | Cyber |
| Atomic state update + audit (`DB.batch`) | PLANNED | Backend |
| Per-user rate limits after auth | PLANNED | Backend |

## P2 — If time

- Advanced anomaly detection (claim velocity per user/policy)
- Network fraud analysis (shared bank accounts/devices across claims)
- Dual approval for high-value decisions/payouts
- Monitoring/alerting on `denied` audit spikes
- Malware scanning / CDR for uploads

## Bonus

- Quantum-kernel screening experiment
- Post-quantum signatures over decision records / evidence hashes

Bonus work must not start until P0 authentication and tenant scoping are done, and must never bypass `transitionClaim()` or `requireRole()`.
