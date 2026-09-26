# Security Checklist

Phase 1 update (2026-09-26): the Phase 0 items about `X-Dev-Actor-*` headers, `ALLOW_DEV_ACTOR_HEADERS` and Postman `actorId`/`actorRole` variables are removed because that code path no longer exists (`backend/src/security/actor.ts` accepts only `Authorization: Bearer <JWT>`). Items are replaced, not appended, so this list stays the single pre-demo / pre-deploy gate.

## Pre-demo (local)

- [ ] `cd backend && npm test` — all green (12 files, 175 passed + 1 todo at time of writing; the todo is TENANT-004 evidence isolation, BLOCKED until an evidence endpoint exists)
- [ ] `npm run typecheck` passes (clean at time of writing)
- [ ] `npm audit` — 0 vulnerabilities (0 at time of writing)
- [ ] `npm run db:migrate:local && npm run db:seed:local` applied; migrations `0001_init`, `0002_security` and `0003_tenants` all listed as applied (`0003` adds `tenants`, `policies.tenant_id`, `claims.tenant_id`, `audit_events.actor_tenant_id`)
- [ ] `npm run setup:local` has been run once: `backend/.dev.vars` exists with a randomly generated `JWT_SECRET` (>= 32 bytes, never the `CHANGE_ME` placeholder from `.dev.vars.example`). The API answers 401 to everything until this is true (fail closed; TESTED/PASSED AUTH-009/010)
- [ ] `backend/.dev.vars` is **not** committed (`.gitignore` covers `.dev.vars` and `.dev.vars.*` except `.dev.vars.example`)
- [ ] `JWT_ISSUER` and `JWT_AUDIENCE` are present in `backend/wrangler.toml` `[vars]` (`easyclaim-dev` / `easyclaim-api` locally)
- [ ] Demo tokens minted with a bounded lifetime: `npm run token -- --demo` (prints one token per demo actor) or `npm run token -- --postman` (writes `backend/postman/EasyClaim.local.postman_environment.json`). Default TTL 3600 s; the script refuses more than 8 h − 60 s for staff and 24 h − 60 s for customers, mirroring `MAX_TOKEN_TTL_SECONDS`. Re-mint before the demo if the previous tokens are older than the TTL
- [ ] `backend/postman/EasyClaim.local.postman_environment.json` is **not** committed (`.gitignore`: `postman/*.postman_environment.json`); the committed collection `backend/EasyClaim.postman_collection.json` holds no tokens
- [ ] Demo narration states that tokens are locally minted HS256 JWTs (not an identity provider), that there is no revocation (PLANNED), and that `/pay` is a state transition with no money movement
- [ ] Show, from Postman folders `0 - Unauthenticated`, `5 - Cross-tenant attack`, `6 - Role attacks`, `7 - Token attacks`: forged / expired / `alg=none` / tampered token 401; cross-tenant read and transition 404; customer → insurer route 403; assessor → `/pay` 403; mass-assignment on `/decide` 400; replay of `/pay` 409; `/pay` before a decision 409. Expected results were captured live in `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log`
- [ ] Confirm no demo material still sends `X-Dev-Actor-*` headers (they are ignored; a request carrying them without a token gets 401, TESTED/PASSED AUTH-011)

## Pre-deploy

- [ ] `JWT_SECRET` set with `wrangler secret put JWT_SECRET` in **each** deployed environment, value >= 32 random bytes (`npm run secret` generates one). It must never appear in `wrangler.toml`, in `[vars]`, in git, or in CI logs
- [ ] `JWT_ISSUER` / `JWT_AUDIENCE` are **distinct per environment** (the current `easyclaim-dev` / `easyclaim-api` values are development values). Per-environment `[env.staging]` / `[env.production]` sections in `wrangler.toml` are PLANNED — today there is a single configuration, so change the values before deploying
- [ ] A token issuer for the deployed environment exists: `backend/scripts/mint-token.mjs` is local-only. Options are a signing service holding the same `JWT_SECRET`, or the identity-provider path (`hono/jwt` `verifyWithJwks`, documented in `actor.ts`, NOT IMPLEMENTED)
- [ ] Key rotation and token revocation are NOT IMPLEMENTED; the compensating controls are the bounded TTL (8 h staff / 24 h customer) and rotating `JWT_SECRET` (which invalidates every token). Accept explicitly or plan before go-live
- [ ] `ALLOWED_ORIGINS` set to the real frontend origin(s) only
- [ ] `wrangler.toml` `database_id` points at the real D1 database (current value is a local mock)
- [ ] `[[ratelimits]] namespace_id` is unique within the Cloudflare account; note both the per-IP and the per-actor limiter share the one `RATE_LIMITER` binding and are approximate
- [ ] `wrangler d1 migrations apply easy-claim-db --remote` run through `0003_tenants`; audit triggers `audit_events_no_update` / `audit_events_no_delete` present; `audit_events.actor_tenant_id` present
- [ ] The `0003` backfill only assigns the five seed policy ids; every other pre-existing policy/claim keeps `tenant_id NULL` and is therefore invisible to all insurer staff (fail closed). Verify no production row is left with `tenant_id NULL` unintentionally
- [ ] Seed data (`seed_sa_data.sql`) **not** loaded into production; the five demo tenants inserted by `0003_tenants.sql` (`INSERT OR IGNORE`) replaced by real tenant rows
- [ ] Tenant scoping for insurer roles: IMPLEMENTED for claims (`loadAuthorizedClaim`, `GET /claims`, `transitionClaim`); evidence tenant isolation BLOCKED (no evidence endpoint) — do not ship evidence upload without it
- [ ] Cloudflare account access to D1 restricted (an admin can drop the audit triggers)
- [ ] `npm test`, `npm run typecheck` and `npm audit` green in CI
- [ ] No secrets in git history: review `git log -p | grep -i secret` and confirm `backend/.dev.vars` and `backend/postman/*.postman_environment.json` never appear in `git log --all --name-only`
- [ ] Open decisions resolved and recorded (DECISION REQUIRED): may ASSESSORs decide; decider ≠ payer; appeal count limit; ADMIN with or without tenant; per-tenant claimant reference instead of the platform `user_id`
- [ ] Known open items acknowledged: queue consumer not observed firing under `wrangler dev`; `/profile`, `/client/*`, `/activities/*` remain demo stubs; `GET /profile/mandates/:tenantId/check` ignores its parameter; audit retention/export NOT IMPLEMENTED
