# Security Checklist

## Pre-demo (local)

- [ ] `cd backend && npm test` — all green (85/85 at time of writing)
- [ ] `npm run typecheck` passes
- [ ] `npm audit` — 0 vulnerabilities
- [ ] `npm run db:migrate:local && npm run db:seed:local` applied
- [ ] `backend/.dev.vars` exists locally (copied from `.dev.vars.example`) and is **not** committed
- [ ] Demo narration states that `X-Dev-Actor-*` headers are a dev stub, not authentication
- [ ] Postman `actorId` / `actorRole` variables set for the demo persona
- [ ] Show: IDOR 404, customer→`/ocr/process` 403, mass-assignment 400, double-submit 409

## Pre-deploy

- [ ] Real authentication replaces `resolveActor()` (BACKEND-SEC-001)
- [ ] `ALLOW_DEV_ACTOR_HEADERS` is **not** set anywhere in the deployed environment (not in `wrangler.toml`, not a secret)
- [ ] `ALLOWED_ORIGINS` set to the real frontend origin(s) only
- [ ] `wrangler.toml` `database_id` points at the real D1 database (current value is a local mock)
- [ ] `[[ratelimits]] namespace_id` is unique within the Cloudflare account
- [ ] `wrangler d1 migrations apply easy-claim-db --remote` run; audit triggers present
- [ ] Seed data (`seed_sa_data.sql`) **not** loaded into production
- [ ] Tenant/org scoping implemented for insurer roles (BACKEND-SEC-002)
- [ ] Cloudflare account access to D1 restricted (can drop audit triggers)
- [ ] `npm test` and `npm audit` green in CI
- [ ] No secrets in git history (`git log -p | grep -i secret` review)
