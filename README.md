# EasyClaim Backend

## Overview

EasyClaim is a claims-orchestration platform concept for South African insurance customers. It gives customers one place to see their covers, start a claim, go through a guided claim process, and track it. Insurer staff (assessors, managers, admins) work the same claims from an insurer portal.

**This repository currently contains the backend API only.**

- **Backend only.** The `frontend/` folder contains a zustand state store and TypeScript types. **There is no frontend/UI** in this repository.
- The API runs locally on Cloudflare Workers tooling (`wrangler dev`) with a local D1 database.
- Much of the API is still stubbed or returns demo data. The table below lists exactly what is implemented.
- **Real authentication is not implemented.** Locally, requests identify the caller through a spoofable dev-only header stub (see [Running Locally](#running-locally)).

## Product Concept

The intended claim journey is:

**Submitted → Verified → Screening → Review → Decision → Paid**

Planned side states: **Info Needed**, **Appeal**, **Withdrawn**, **Expired**.

The server-side state machine (`backend/src/security/claimStateMachine.ts`) defines all of these stages, plus a `Draft` pre-state. Only the customer transitions are reachable through the API today:

- Draft → Submitted
- Info Needed → Screening
- Decision → Appeal

Insurer transitions (verify, screen, review, decide, pay) have no endpoints yet.

Intended user experiences:

1. **Client**: see covers, file and track claims.
2. **Insurer**: an insurer portal with the roles Assessor, Manager and Admin. These are planned; no insurer UI or insurer workflow endpoints exist.

## Current Implementation

| Capability | Status | Evidence |
|------------|--------|----------|
| API server | Implemented | `backend/src/index.ts` (Hono on Cloudflare Workers) |
| Authentication | Not found (fails closed; dev-only header stub) | `backend/src/security/actor.ts` |
| Authorization/RBAC | Partial (role checks on customer-only and insurer-only routes; no tenant scoping) | `backend/src/security/rbac.ts` |
| Claims | Partial (initiate, screening, submit, appeal persisted in D1) | `backend/src/endpoints/claims.ts` |
| Claim lifecycle | Partial (full transition table; only customer transitions exposed) | `backend/src/security/claimStateMachine.ts`, `backend/src/security/claimAccess.ts` |
| Evidence upload | Not found (endpoint queues an event only; no file accepted or stored) | `POST /api/v1/claims/:claimId/evidence-ocr` |
| OCR/text extraction | Not found (stub endpoint + queue consumer that logs) | `backend/src/endpoints/ocr.ts` |
| Screening | Partial (customer narrative stored; no fraud/risk logic) | `PATCH /api/v1/claims/:claimId/screening` |
| Review | Planned | state machine only |
| Decisions | Partial (read-only from D1; no insurer decision endpoint) | `GET /api/v1/claims/:claimId/decision` |
| Payouts | Planned | state machine reserves Decision→Paid for MANAGER |
| Audit logging | Implemented (append-only `audit_events` table) | `backend/src/security/audit.ts`, `backend/migrations/0002_security.sql` |
| Notifications | Partial (hard-coded demo data) | `backend/src/endpoints/gateway.ts` |
| Database | Implemented (Cloudflare D1 + migrations) | `backend/wrangler.toml`, `backend/migrations/` |
| Tests | Implemented (9 files, 85 tests, passing) | `backend/test/` |

## API

All routes are under `/api/v1`. Every route requires a resolved actor (currently the dev stub) and returns `401 {"error":"unauthenticated"}` otherwise. Inputs are validated with strict schemas: unknown fields are rejected with `400`. Claims the caller may not access return `404`.

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
| POST | `/claims/verify-eligibility` | Check a policy is owned + Active | actor | CUSTOMER | `{ policyId }` | `verified`, `context` | Identity and waiting period are `null` (not implemented) |
| POST | `/claims/initiate` | Create a Draft claim | actor | CUSTOMER | `{ policyId, category? }` | `status`, `claimId` | Policy must be owned and Active; ID is `claim_<uuid>` |
| PATCH | `/claims/:claimId/screening` | Save cause of loss | actor | CUSTOMER (owner) | `{ causeOfLoss, incidentDate }` | `status`, `message` | Only in Draft / Info Needed |
| POST | `/claims/:claimId/evidence-ocr` | Queue evidence processing | actor | CUSTOMER (owner) | — | `status`, `message` (202) | No file upload yet |
| POST | `/claims/:claimId/submit` | Submit claim | actor | CUSTOMER (owner) | — | `status`, `message`, `claimId` | Draft→Submitted; repeat gives 409 |
| GET | `/claims/:claimId/timeline` | Track claim | actor | owner, ASSESSOR, MANAGER | — | `claimId`, `currentStage`, `timeline[]` | |
| GET | `/claims/:claimId/decision` | Decision status | actor | owner, ASSESSOR, MANAGER | — | `decision` | Read-only |
| POST | `/claims/:claimId/appeal` | Appeal a rejection | actor | CUSTOMER (owner) | `{ reason }` | `status` | Only for rejected decisions |
| POST | `/ocr/process` | OCR stub | actor | ASSESSOR, MANAGER | — | `extracted` | Stub |
| GET | `/profile` | Profile | actor | any | — | `profile` | Stub (empty) |
| PATCH | `/profile` | Update profile | actor | any | — | `updated` | Stub, no-op |
| GET | `/profile/consent` | Consent | actor | any | — | `consent` | Stub |
| GET | `/profile/mandates/:tenantId/check` | Mandate check | actor | any | — | `active` | Stub, no object check |
| POST | `/profile/mandates/cancel` | Cancel mandate | actor | CUSTOMER | — | `cancelled` | Stub, audited |
| GET | `/activities/history` | History | actor | any | — | `history[]` | Stub (empty) |
| GET | `/activities/audit-trail` | Audit trail | actor | any | — | `trail[]` | Stub (empty); does not read `audit_events` |

The full per-endpoint security view is in [docs/security/API_SECURITY_MATRIX.md](docs/security/API_SECURITY_MATRIX.md). A Postman collection is in `backend/EasyClaim.postman_collection.json`.

## Running Locally

Requirements: Node.js (verified with v24).

```bash
cd backend
npm install
cp .dev.vars.example .dev.vars      # local-only settings, gitignored
npm run db:migrate:local            # apply migrations/ to the local D1 database
npm run db:seed:local               # load South African demo data
npm run dev                         # http://127.0.0.1:8787
```

> Windows note: keep the clone in a short path (e.g. `C:\dev\Easy-Claim`). In a very long path, `wrangler d1 ... --local` fails with `internal error` / `d1 execute local query failed` (verified on Windows 11, wrangler 4.141).

Run the checks:

```bash
npm test            # vitest in the Workers runtime: 9 files, 85 tests
npm run typecheck   # tsc --noEmit
```

Call the API as a demo customer:

```bash
curl http://127.0.0.1:8787/api/v1/covers/my-covers \
  -H "X-Dev-Actor-Id: user123" \
  -H "X-Dev-Actor-Role: CUSTOMER"
```

> ⚠️ **The `X-Dev-Actor-*` headers are a dev stub, NOT authentication.** Anyone can claim to be anyone with them. They only work when `ALLOW_DEV_ACTOR_HEADERS=true` is set in `.dev.vars`. Without it, every request gets `401`. Never set this variable in a deployed environment. Real authentication replaces `resolveActor()` in `backend/src/security/actor.ts`.

Demo actors: `user123`, `user456`, `user789` (CUSTOMER, from seed data). Any id with role `ASSESSOR`, `MANAGER` or `ADMIN` acts as insurer staff.

## Environment Variables

| Name | Required | Where | Purpose |
|---|---|---|---|
| `ALLOW_DEV_ACTOR_HEADERS` | Local dev/testing only | `.dev.vars` | Enables the dev actor header stub. Must not exist in deployed environments |
| `ALLOWED_ORIGINS` | Optional | `wrangler.toml` `[vars]` (empty by default), `.dev.vars` | Comma-separated CORS origin allowlist |

Bindings configured in `backend/wrangler.toml` (not secrets):

- `DB`: D1 database.
- `CLAIM_EVENTS`: queue.
- `RATE_LIMITER`: 100 requests / 60 s per client IP.

No secrets are required today. There are no secret values in the repository.

## Project Structure

```
backend/
  src/
    index.ts              app, global middleware, queue handler
    types.ts              roles, bindings, actor types
    endpoints/            route handlers (gateway, policy, claims, ocr, identity, audit)
    models/policyModel.ts policy queries
    security/             actor, rbac, claimAccess, claimStateMachine, audit, validation
  migrations/             D1 schema migrations
  seed_sa_data.sql        demo data
  test/                   vitest security and lifecycle tests
  wrangler.toml           Worker, D1, queue, rate-limit config
  EasyClaim.postman_collection.json
frontend/
  src/store/useAppStore.ts  zustand store (no UI)
  src/types/index.ts        shared types
docs/
  BACKEND_INVENTORY.md
  architecture/BACKEND_ARCHITECTURE.md
  security/                 security documentation
```

## Security

See [docs/security/README.md](docs/security/README.md).

## Development Status

**Implemented and tested:**

- Claim ownership checks (IDOR/BOLA).
- Role checks.
- Strict input validation (mass-assignment protection).
- Claim state machine.
- Append-only audit trail.
- Rate limiting, security headers, CORS allowlist, body size limit, generic error responses.

**Not implemented / planned:**

- Real authentication.
- Insurer workflow endpoints (verify, screen, review, decide).
- Evidence upload and storage.
- OCR/AI.
- Fraud screening.
- Payouts.
- Notifications.
- Profile, consent and mandate logic.
- Tenant scoping for insurer staff.
- A frontend/UI.

See [docs/security/SECURITY_IMPLEMENTATION_PLAN.md](docs/security/SECURITY_IMPLEMENTATION_PLAN.md) and [docs/security/BACKEND_SECURITY_HANDOFF.md](docs/security/BACKEND_SECURITY_HANDOFF.md).
