# EasyClaim Backend

## Overview

EasyClaim is a claims-orchestration platform concept for South African insurance customers. It gives customers one place to see their covers, start a claim, go through a guided claim process, and track it. Insurer staff (assessors, managers, admins) work the same claims from an insurer portal.

**This repository currently contains the backend API only.**

- **Backend only.** The `frontend/` folder contains a zustand state store and TypeScript types. **There is no frontend/UI** in this repository.
- The API runs locally on Cloudflare Workers tooling (`wrangler dev`) with a local D1 database.
- Much of the API is still stubbed or returns demo data. The table below lists exactly what is implemented.
- **Authentication (Phase 1): every `/api/v1/*` request needs `Authorization: Bearer <JWT>`.** The Worker verifies the token itself (HS256 with a pinned algorithm, issuer, audience and expiry checks) in `src/security/actor.ts`. There is no identity provider yet: local tokens are minted with `npm run token` (see [Running Locally](#running-locally)). The Phase 0 `X-Dev-Actor-*` header stub and `ALLOW_DEV_ACTOR_HEADERS` no longer exist.
- **Tenants (Phase 1):** insurer staff (ASSESSOR, MANAGER) belong to exactly one insurer tenant (`tenant_id` token claim) and only see that tenant's submitted claims. Customers are platform-level (no tenant; one customer can hold policies with several insurers) and see their own claims.

## Product Concept

The intended claim journey is:

**Submitted → Verified → Screening → Review → Decision → Paid**

Planned side states: **Info Needed**, **Appeal**, **Withdrawn**, **Expired**.

The server-side state machine (`src/security/claimStateMachine.ts`, unchanged in Phase 1) defines all of these stages, plus a `Draft` pre-state. Since Phase 1 every insurer transition, and every customer transition except Withdrawn, is reachable over HTTP:

- Customer: Draft → Submitted (`POST /claims/:claimId/submit`), Info Needed → Screening (`PATCH /claims/:claimId/screening`), Decision → Appeal (`POST /claims/:claimId/appeal`).
- Insurer (ASSESSOR/MANAGER of the claim's tenant, `src/endpoints/claimsInsurer.ts`): Submitted → Verified (`/verify`), Verified → Screening (`/screen`), Screening → Review and Appeal → Review (`/review`; Appeal → Review is MANAGER-only), Screening/Review → Info Needed (`/request-info`), Review → Decision (`/decide` with outcome `Approved` or `Rejected`), Decision → Paid (`/pay`, MANAGER-only, state transition only).
- Not reachable: Withdrawn (a CUSTOMER edge in the table, no endpoint) and Expired (a SYSTEM edge, no scheduled job). ADMIN has no claim transitions.

Intended user experiences:

1. **Client**: see covers, file and track claims.
2. **Insurer**: an insurer portal with the roles Assessor, Manager and Admin. The insurer workflow endpoints exist since Phase 1 (see [API](#api)); there is no insurer UI, and decision records (amount, reason) and payment execution are NOT IMPLEMENTED.

## Current Implementation

| Capability | Status | Evidence |
|------------|--------|----------|
| API server | IMPLEMENTED | `src/index.ts` (Hono on Cloudflare Workers) |
| Authentication | IMPLEMENTED (HS256 JWT verified by the app: pinned `alg`, `iss`/`aud`, required `exp`/`iat`, per-role maximum lifetime; fails closed when `JWT_SECRET`/`JWT_ISSUER`/`JWT_AUDIENCE` are missing). Identity provider / JWKS: PLANNED. Token revocation: PLANNED | `src/security/actor.ts`, `test/auth.test.ts` |
| Authorization/RBAC | IMPLEMENTED (coarse role gate per route, object-level check per claim incl. tenant scoping for insurer staff and ownership for customers, per-transition role in the state machine) | `src/security/rbac.ts`, `src/security/claimAccess.ts` |
| Tenant model | IMPLEMENTED (`tenants` table; `policies.tenant_id`, `claims.tenant_id`, `audit_events.actor_tenant_id`; a claim inherits its policy's tenant). Tenant admin functions: NOT IMPLEMENTED | `migrations/0003_tenants.sql`, `test/tenant.test.ts` |
| Claims | PARTIAL (initiate, screening, submit, appeal and list persisted in D1; no evidence) | `src/endpoints/claims.ts` |
| Claim lifecycle | IMPLEMENTED state machine; over HTTP PARTIAL (all insurer transitions plus the customer transitions Draft → Submitted, Info Needed → Screening and Decision → Appeal; Withdrawn and Expired have no endpoint or job) | `src/security/claimStateMachine.ts`, `src/security/claimAccess.ts`, `src/endpoints/claimsInsurer.ts` |
| Evidence upload | NOT IMPLEMENTED (endpoint queues an event only; no file accepted or stored; the `evidence` table is unused) | `POST /api/v1/claims/:claimId/evidence-ocr` |
| OCR/text extraction | NOT IMPLEMENTED (stub endpoint + queue consumer that logs) | `src/endpoints/ocr.ts` |
| Screening | PARTIAL (customer narrative stored; insurer `/screen` and `/request-info` move the stage; no fraud/risk logic) | `PATCH /api/v1/claims/:claimId/screening`, `src/endpoints/claimsInsurer.ts` |
| Review | PARTIAL (stage transition via `/review`; no review record) | `src/endpoints/claimsInsurer.ts` |
| Decisions | PARTIAL (outcome only: `/decide` writes `Approved`/`Rejected` to `claims.status`; no amount, reason or decision record) | `POST /api/v1/claims/:claimId/decide`, `GET /api/v1/claims/:claimId/decision` |
| Payouts | PARTIAL (`/pay` is a MANAGER-only Decision → Paid state transition that requires an approved decision; no payment execution, no bank details) | `POST /api/v1/claims/:claimId/pay` |
| Audit logging | IMPLEMENTED (append-only `audit_events` incl. acting tenant and server-generated request id; a stage change and its audit row are written in one D1 batch) | `src/security/audit.ts`, `migrations/0002_security.sql`, `migrations/0003_tenants.sql` |
| Notifications | PARTIAL (hard-coded demo data) | `src/endpoints/gateway.ts` |
| Database | IMPLEMENTED (Cloudflare D1 + 3 migrations) | `wrangler.toml`, `migrations/` |
| Tests | TESTED/PASSED (12 files, 183 passed + 1 todo; the todo is TENANT-004 evidence isolation, BLOCKED until an evidence endpoint exists) | `test/` |

## API

All routes are under `/api/v1`. Every route requires a verified bearer token (`Authorization: Bearer <JWT>`, see [Running Locally](#running-locally)) and returns `401 {"error":"unauthenticated"}` with `WWW-Authenticate: Bearer` otherwise; "actor" in the Auth column means that verified token. Request bodies are validated with strict schemas: unknown fields are rejected with `400` (the `GET /claims` query schema validates `limit` only; other query parameters are ignored, not rejected). A claim the caller may not access (another customer's, another tenant's, an unsubmitted Draft for insurer staff, or non-existent) returns the same `404 {"error":"not_found"}` and is audited. Role denials return `403`. Insurer routes are per tenant: staff only act on claims whose `tenant_id` equals the `tenant_id` in their token.

| Method | Route | Purpose | Auth | Role | Request | Response | Notes |
|---|---|---|---|---|---|---|---|
| GET | `/client/home` | Dashboard banner | actor | any | — | `message`, `alerts[]` | Demo data |
| GET | `/client/services/most-visited` | Shortcuts | actor | any | — | `data[]` | Demo data |
| GET | `/client/notifications` | Notifications | actor | any | — | `notifications[]` | Demo data, not user-scoped |
| GET | `/client/activity/recent` | Recent activity | actor | any | — | `activity[]` | Demo data |
| GET | `/covers/my-covers` | Caller's policies | actor | CUSTOMER | — | `policies[]` | From D1, scoped to caller |
| GET | `/covers/market-catalog` | Plan catalog | actor | any | — | `catalog[]` | Static list |
| POST | `/covers/join-request` | Request to join a plan | actor | CUSTOMER | `{ planId }` | `status`, `message`, `planId`, `provider` | Audited |
| GET | `/claims/status` | Service status | actor | any | — | `status` | |
| GET | `/claims` | List claims (Phase 1) | actor | CUSTOMER (own claims); ASSESSOR, MANAGER (their tenant's claims, Draft excluded, no `user_id`); ADMIN → 403 audited | `?limit=1..50` (default 20) | `claims[]` | Newest first |
| POST | `/claims/verify-eligibility` | Check a policy is owned + Active | actor | CUSTOMER | `{ policyId }` | `verified`, `context` | Identity and waiting period are `null` (not implemented) |
| POST | `/claims/initiate` | Create a Draft claim | actor | CUSTOMER | `{ policyId, category? }` | `status`, `claimId` | Policy must be owned, Active and have a tenant (else `422 policy_not_eligible`); the claim copies the policy's `tenant_id`; ID is `claim_<uuid>` |
| PATCH | `/claims/:claimId/screening` | Save cause of loss | actor | CUSTOMER (owner) | `{ causeOfLoss, incidentDate }` | `status`, `message` | Only in Draft / Info Needed (precondition repeated in the SQL `UPDATE`); from Info Needed also moves the claim back to Screening |
| POST | `/claims/:claimId/evidence-ocr` | Queue evidence processing | actor | CUSTOMER (owner) | — | `status`, `message` (202) | No file upload yet |
| POST | `/claims/:claimId/submit` | Submit claim | actor | CUSTOMER (owner) | — | `status`, `message`, `claimId` | Draft→Submitted; repeat gives 409 |
| GET | `/claims/:claimId/timeline` | Track claim | actor | owner; ASSESSOR, MANAGER of the claim's tenant (not for Draft) | — | `claimId`, `currentStage`, `timeline[]` | A stage is `completed` when the audit trail shows it was reached or the claim is at/after it on the main path |
| GET | `/claims/:claimId/decision` | Decision status | actor | owner; ASSESSOR, MANAGER of the claim's tenant (not for Draft) | — | `decision` | Read-only (`claims.status` once in Decision/Paid, else `pending`) |
| POST | `/claims/:claimId/appeal` | Appeal a rejection | actor | CUSTOMER (owner) | `{ reason }` | `status` | Only for rejected decisions |
| POST | `/claims/:claimId/verify` | Submitted → Verified (Phase 1) | actor | ASSESSOR, MANAGER (claim's tenant) | — | `status`, `claimId`, `from`, `to` | 404 for other tenants / Drafts; 409 `illegal_transition` or `stale_state` |
| POST | `/claims/:claimId/screen` | Verified → Screening (Phase 1) | actor | ASSESSOR, MANAGER (claim's tenant) | — | `status`, `claimId`, `from`, `to` | Stage change only; no screening logic |
| POST | `/claims/:claimId/review` | Screening → Review, Appeal → Review (Phase 1) | actor | ASSESSOR, MANAGER (claim's tenant); Appeal → Review MANAGER only (403 for ASSESSOR) | — | `status`, `claimId`, `from`, `to` | |
| POST | `/claims/:claimId/request-info` | Screening / Review → Info Needed (Phase 1) | actor | ASSESSOR, MANAGER (claim's tenant) | — | `status`, `claimId`, `from`, `to` | The customer answers with `PATCH /claims/:claimId/screening` |
| POST | `/claims/:claimId/decide` | Review → Decision (Phase 1) | actor | ASSESSOR, MANAGER (claim's tenant) | `{ outcome: "Approved" \| "Rejected" }` (strict) | `status`, `claimId`, `from`, `to`, `outcome` | Outcome written to `claims.status` in the same statement as the stage; no amount, reason or decision record |
| POST | `/claims/:claimId/pay` | Decision → Paid (Phase 1) | actor | MANAGER (claim's tenant); ASSESSOR → 403 | — | `status`, `claimId`, `from`, `to` | 409 `not_approved` unless `claims.status` is `Approved`; state transition only, **no payment is executed** |
| POST | `/ocr/process` | OCR stub | actor | ASSESSOR, MANAGER | — | `extracted` | Stub |
| GET | `/profile` | Profile | actor | any | — | `profile` | Stub (empty) |
| PATCH | `/profile` | Update profile | actor | any | — | `updated` | Stub, no-op |
| GET | `/profile/consent` | Consent | actor | any | — | `consent` | Stub |
| GET | `/profile/mandates/:tenantId/check` | Mandate check | actor | any | — | `active` | Stub, no object check |
| POST | `/profile/mandates/cancel` | Cancel mandate | actor | CUSTOMER | — | `cancelled` | Stub, audited |
| GET | `/activities/history` | History | actor | any | — | `history[]` | Stub (empty) |
| GET | `/activities/audit-trail` | Audit trail | actor | any | — | `trail[]` | Stub (empty); does not read `audit_events` |

The full per-endpoint security view is in [docs/security/API_SECURITY_MATRIX.md](docs/security/API_SECURITY_MATRIX.md). A Postman collection is in `EasyClaim.postman_collection.json`; it takes its bearer tokens from a generated, gitignored environment file (`postman/EasyClaim.local.postman_environment.json`, written by `npm run token -- --postman`). Folders 0, 5, 6 and 7 of the collection are attack demos (no token or the retired `X-Dev-Actor-*` headers → 401, cross-tenant → 404, wrong role → 403, tampered signature / `alg=none` / non-Bearer credentials → 401).

## Running Locally

Requirements: Node.js (verified with v24).

```bash
npm install
npm run setup:local                 # creates .dev.vars (gitignored) with a random JWT_SECRET; never overwrites an existing file
npm run db:migrate:local            # apply migrations/ to the local D1 database (0003 creates the demo tenants)
npm run db:seed:local               # load South African demo data (policies and claims carry tenant_id)
npm run dev                         # http://127.0.0.1:8787
```

Without a `JWT_SECRET` of at least 32 bytes (or without `JWT_ISSUER` / `JWT_AUDIENCE`) the API answers every request with `401` and logs `auth misconfigured`; it never falls open.

> Windows note: keep the clone in a short path (e.g. `C:\dev\Easy-Claim`). In a very long path, `wrangler d1 ... --local` fails with `internal error` / `d1 execute local query failed` (verified on Windows 11, wrangler 4.141).

Run the checks:

```bash
npm test            # vitest in the Workers runtime: 12 files, 183 passed + 1 todo (measured 2026-09-26)
npm run typecheck   # tsc --noEmit
npm audit           # 0 vulnerabilities at the time of writing
```

Mint a local token and call the API (`scripts/mint-token.mjs` signs with the `JWT_SECRET` from `.dev.vars`):

```bash
npm run token -- --demo                                            # one token per demo actor, printed with a comment
npm run token -- --postman                                         # writes postman/EasyClaim.local.postman_environment.json (gitignored)
npm run token -- --sub user123 --role CUSTOMER                     # a specific customer
npm run token -- --sub assessor_a1 --role ASSESSOR --tenant ins_discovery   # insurer staff need --tenant

TOKEN=$(npm run -s token -- --sub user123 --role CUSTOMER)
curl http://127.0.0.1:8787/api/v1/covers/my-covers -H "Authorization: Bearer $TOKEN"
curl http://127.0.0.1:8787/api/v1/claims -H "Authorization: Bearer $TOKEN"
```

> Tokens are local-only: they are signed with the secret in your `.dev.vars` and are worthless elsewhere. The mint script mirrors the server's claim rules (`iat` backdated 60 s; `--ttl` defaults to 3600 s and is capped 60 s below the server maximum of 24 h for CUSTOMER and 8 h for ASSESSOR/MANAGER/ADMIN; `tenant_id` required for ASSESSOR/MANAGER and forbidden for CUSTOMER) and refuses to mint a token the server would reject. `--iss`, `--aud` and `--secret` override `.dev.vars` / `wrangler.toml` for negative tests. A deployed environment must receive tokens from a real identity provider or auth service: PLANNED, the documented path is `hono/jwt` `verifyWithJwks` (NOT IMPLEMENTED). There is no token revocation (PLANNED).

Demo actors (`--demo` / `--postman`): `user123` (CUSTOMER; Discovery, Sanlam and Old Mutual policies), `user456` (CUSTOMER; OUTsurance policy, no claims), `assessor_a1` and `manager_a1` (tenant `ins_discovery`), `assessor_b1` and `manager_b1` (tenant `ins_sanlam`), `admin1` (ADMIN, no claim access). `user789` from the seed can be minted with `--sub user789 --role CUSTOMER`. Seed tenants: `ins_discovery`, `ins_sanlam`, `ins_outsurance`, `ins_momentum`, `ins_oldmutual`.

## Environment Variables

| Name | Required | Where | Purpose |
|---|---|---|---|
| `JWT_SECRET` | Yes (**secret**) | `.dev.vars` locally (created by `npm run setup:local`, gitignored); `wrangler secret put JWT_SECRET` when deployed. Never in `wrangler.toml` | HS256 signing secret, at least 32 bytes (`npm run secret` prints a random one). Missing or too short → every request `401`, logged as `auth misconfigured` |
| `JWT_ISSUER` | Yes | `wrangler.toml` `[vars]` (`easyclaim-dev`); can be overridden in `.dev.vars` | Expected `iss` claim. Missing → every request `401` |
| `JWT_AUDIENCE` | Yes | `wrangler.toml` `[vars]` (`easyclaim-api`); can be overridden in `.dev.vars` | Expected `aud` claim (string or array containing it). Missing → every request `401` |
| `ALLOWED_ORIGINS` | Optional | `wrangler.toml` `[vars]` (empty by default), `.dev.vars` | Comma-separated CORS origin allowlist |

`ALLOW_DEV_ACTOR_HEADERS` (Phase 0) was removed together with the header stub; setting it has no effect.

Bindings configured in `wrangler.toml` (not secrets):

- `DB`: D1 database.
- `CLAIM_EVENTS`: queue.
- `RATE_LIMITER`: 100 requests / 60 s, applied twice on the same binding: per client IP before authentication (`/api/*`) and per actor (`actor:<role>:<id>`) after it (`/api/v1/*`).

`JWT_SECRET` is the only secret. It is not in the repository: `.dev.vars` is gitignored and `.dev.vars.example` holds the placeholder `CHANGE_ME`, which the mint script and the server both reject. Per-environment wrangler configuration (`[env.production]`) and key rotation are NOT IMPLEMENTED.

## Project Structure

```
src/
  index.ts              app, request id, global middleware, per-IP and per-actor rate limits, queue handler
  types.ts              roles, bindings (incl. JWT_* settings), Actor { id, role, tenantId }
  endpoints/            route handlers (gateway, policy, claims, claimsInsurer, ocr, identity, audit)
  models/policyModel.ts policy queries
  security/             actor (JWT verification), rbac, claimAccess (tenant + ownership, transitions), claimStateMachine, audit, validation
  controllers/ routes/ services/   backend-team MVC layer, NOT mounted by index.ts; if mounted it must sit behind requireActor and use loadAuthorizedClaim/transitionClaim
migrations/             D1 schema migrations (0001_init, 0002_security, 0003_tenants)
scripts/                setup-dev-vars.mjs (npm run setup:local), mint-token.mjs (npm run token)
seed_sa_data.sql        demo data (policies/claims with tenant_id)
test/                   vitest security, tenant, auth and lifecycle tests
wrangler.toml           Worker, D1, queue, rate-limit config, JWT_ISSUER / JWT_AUDIENCE vars
.dev.vars.example       local settings template (JWT_SECRET placeholder, ALLOWED_ORIGINS)
EasyClaim.postman_collection.json
postman/                generated Postman environment with local tokens (gitignored)
lib/                      Flutter mobile app (backend team). Untrusted API client; out of scope for the security docs
docs/security/            threat model, controls, test plan, attack scenarios, handoff
docs/phase-reports/       per-phase verified reports and evidence
```

## Security

See [docs/security/README.md](docs/security/README.md).

## Development Status

**Implemented and tested (Phase 0 + Phase 1):**

- Bearer JWT authentication (HS256, verified by the app; fails closed on missing configuration; 401 bodies and logs never contain the token).
- Claim ownership checks (IDOR/BOLA) and tenant isolation for insurer staff (cross-tenant, unsubmitted Draft and missing claims are indistinguishable: 404).
- Role checks (coarse per route, per transition in the state machine; ADMIN has no claim access).
- Strict input validation (mass-assignment protection), incl. the insurer `decide` body.
- Claim state machine with every insurer transition and every customer transition except Withdrawn reachable over HTTP; stage change and audit row written in one D1 batch; replay/race → 409.
- Append-only audit trail with acting tenant and server-generated request id.
- Rate limiting (per IP, then per actor), security headers, CORS allowlist, body size limit, generic error responses.
- Live attack evidence against `wrangler dev`: [docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log](docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log) (ATTACK-P1-001 to -012: forged/expired/tampered/`alg=none`/HS512/over-TTL tokens → 401; cross-tenant read and transition → 404, same body as a missing claim; customer on insurer routes → 403; assessor payout → 403; retired dev headers → 401 without a token and ignored with one; IDOR → 404; ADMIN list → 403; full Submitted → Paid path with pay-before-decision and replay → 409; audit rows counted per action, role and tenant).

**Not implemented / planned / decision required:**

- Identity provider or JWKS verification (PLANNED: `hono/jwt` `verifyWithJwks`), token revocation / `jti` denylist (PLANNED), key rotation, per-environment wrangler config (`[env.production]`).
- Evidence upload and storage; evidence tenant isolation (BLOCKED until evidence exists).
- OCR/AI. Fraud screening.
- Decision records (amount, reason) and payment execution: `/decide` and `/pay` only change the stage.
- Withdrawn endpoint and Expired job.
- Notifications. Profile, consent and mandate logic (`GET /profile/mandates/:tenantId/check` ignores its parameter).
- Tenant admin functions.
- DECISION REQUIRED: separation of duties (the same manager may decide and pay); appeal count limit; per-tenant claimant reference (insurer lists omit `user_id`); ADMIN scope (platform vs tenant admin; `tenant_id` is optional on ADMIN tokens).
- Known open from Phase 0: audit triggers can be dropped by a DB admin; the queue consumer does not fire under `wrangler dev` (re-observed in Phase 1); rate limiting is approximate by design of the binding; `/profile`, `/client/*` and `/activities/*` remain demo stubs.
- A frontend/UI.

See [docs/security/SECURITY_IMPLEMENTATION_PLAN.md](docs/security/SECURITY_IMPLEMENTATION_PLAN.md) and [docs/security/BACKEND_SECURITY_HANDOFF.md](docs/security/BACKEND_SECURITY_HANDOFF.md).
