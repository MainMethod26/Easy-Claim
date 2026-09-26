# Security Implementation Plan

Owner: **Cyber** = delivered on branch `cyber`; **Backend** = backend team.

> **Phase 1 update (2026-09-26):** authentication, tenant scoping, insurer transitions over HTTP,
> per-actor rate limits and atomic audit writes moved to IMPLEMENTED. See
> `docs/phase-reports/PHASE_01_REPORT.md` and `docs/security/BACKEND_SECURITY_HANDOFF.md` (015–020 for what is next).

## P0 — Must have

| Item | Status | Owner | Files |
|---|---|---|---|
| Authentication | IMPLEMENTED (Phase 1): app-verified HS256 bearer JWT, pinned alg, required iss/aud/exp/iat, bounded TTL, fail-closed config. IdP / JWKS PLANNED | Cyber (IdP: Backend) | `src/security/actor.ts`, `wrangler.toml` `[vars]`, `.dev.vars.example`, `scripts/mint-token.mjs` |
| Dev actor stub | REMOVED (Phase 1); no non-token path exists | Cyber | — |
| RBAC (function-level) | IMPLEMENTED | Cyber | `src/security/rbac.ts`; applied in `src/endpoints/*.ts` |
| Object-level authorization (claims, policies) | IMPLEMENTED | Cyber | `src/security/claimAccess.ts`, `src/endpoints/claims.ts`, `src/endpoints/policy.ts` |
| Tenant scoping for insurer staff | IMPLEMENTED (Phase 1): `tenant_id` on policies/claims, `isTenantInsurer()`, drafts and NULL-tenant claims hidden | Cyber | `migrations/0003_tenants.sql`, `claimAccess.ts`, `types.ts` |
| Property-level authorization | IMPLEMENTED (incl. `tenant_id`) | Cyber | `src/security/validation.ts` |
| Claim state transition enforcement | IMPLEMENTED for customer AND insurer routes over HTTP (Phase 1); Withdrawn/Expired have no endpoint | Cyber | `claimStateMachine.ts`, `transitionClaim()`, `src/endpoints/claimsInsurer.ts` |
| Evidence access control | PARTIAL (ownership on evidence-ocr route; no files) | Cyber / Backend | `src/endpoints/claims.ts` |
| Evidence validation | NOT IMPLEMENTED (no upload) | Backend | see `EVIDENCE_SECURITY.md` |
| Input validation | IMPLEMENTED for all routes with bodies/params/query | Cyber | `validation.ts` |
| Secrets protection | IMPLEMENTED (`.dev.vars`, generated Postman environment gitignored; per-run test secret; no secrets in repo) | Cyber | `.gitignore`, `.gitignore`, `vitest.config.mts` |
| Audit of sensitive actions | IMPLEMENTED; rows carry `actor_tenant_id` and server-generated `request_id`; state change + audit in one batch | Cyber | `src/security/audit.ts`, `migrations/0002_security.sql`, `0003_tenants.sql` |
| Basic rate/resource limits | IMPLEMENTED (per-IP before auth, per-actor after auth, 64 KB body, list limit ≤ 50) | Cyber | `wrangler.toml`, `src/index.ts` |
| Security headers, CORS allowlist, generic errors | IMPLEMENTED | Cyber | `src/index.ts` |
| Security tests | IMPLEMENTED (183 tests + 1 todo, 12 files) | Cyber | `test/*.test.ts`, `vitest.config.mts` |

## P1 — Important

| Item | Status | Owner |
|---|---|---|
| Identity provider / JWKS verification, key rotation, revocation (`jti` denylist) | PLANNED (BACKEND-SEC-019) | Backend |
| Per-environment `wrangler.toml` (`[env.production]`, distinct issuer/audience, `wrangler secret put --env`) | PLANNED (BACKEND-SEC-018) | Backend |
| Decision record (`claim_decisions`: reason, amount, versions) | PLANNED (BACKEND-SEC-005); outcome-only `/decide` IMPLEMENTED | Backend |
| Separation of duties (decider ≠ payer) | DECISION REQUIRED (BACKEND-SEC-015) | Product / Backend |
| Appeal limit | DECISION REQUIRED (BACKEND-SEC-016) | Product / Backend |
| Per-tenant claimant reference instead of `user_id` | DECISION REQUIRED (BACKEND-SEC-017) | Product / Backend |
| Evidence hashing / tamper detection (SHA-256 into `evidence.sha256`) | PLANNED (table exists) | Backend |
| Payout protection (destination verification, idempotency, step-up) | PLANNED; MANAGER-only `/pay` state transition IMPLEMENTED | Backend |
| Step-up authentication for payout/mandate/banking changes | PLANNED | Backend |
| Configuration versioning + audit | PLANNED (no config exists) | Backend |
| Explainable screening signals | PLANNED | Backend |
| AI/OCR trust boundaries | PLANNED (documented in `AI_SECURITY.md`; queue validation IMPLEMENTED) | Backend |
| Dependency scanning in CI (`npm audit`) | PARTIAL (run manually: 0 vulns) | Cyber |

## P2 — If time

- Advanced anomaly detection (claim velocity per user/policy)
- Network fraud analysis (shared bank accounts/devices across claims)
- Dual approval for high-value decisions/payouts
- Monitoring/alerting on `denied` audit spikes (now filterable by `actor_tenant_id`)
- Malware scanning / CDR for uploads
- Cache the imported HMAC `CryptoKey` in `resolveActor()` (micro-optimisation)

## Bonus

- Quantum-kernel screening experiment
- Post-quantum signatures over decision records / evidence hashes

Bonus work must never bypass `transitionClaim()`, `loadAuthorizedClaim()` or `requireRole()`.
