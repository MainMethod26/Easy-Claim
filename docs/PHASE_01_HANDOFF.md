# EasyClaim Phase 1 handoff

## Starting point

Continue from `main` commit `da07e7c` (the GitHub merge commit for PR #1). It contains the Phase 1 branch commit `cb2588a` and the root-level project restructure.

PR #1 is merged into GitHub `main`. The receiving machine should clone or pull `main`, then create or configure its own `.dev.vars`; never copy a JWT secret between machines.

## What Phase 1 completed

- HS256 bearer-token verification with issuer, audience, expiry, role, and tenant claims.
- Role-based and object-level authorization for customers and insurer staff.
- Tenant-scoped claim access, persisted tenants, and claim-to-policy tenant inheritance.
- Customer and insurer claim-state transitions, including decision and manager-only payout state transition.
- Strict request validation, append-only audit events, request IDs, CORS/security headers, body limits, and approximate rate limits.
- D1 migrations, South African demo seed data, local token minting scripts, Postman coverage, and security tests.

The active Worker entry point is `src/index.ts`. The active Phase 1 routes are under `src/endpoints/`, security code is under `src/security/`, migrations are under `migrations/`, and tests are under `test/`.

## Validation at handoff

Run from the project root:

```powershell
npm.cmd ci
npm.cmd run typecheck
npm.cmd test
```

At handoff, type checking passed and Vitest reported **183 passed, 1 todo**.

For a local Worker, create a fresh secret and database:

```powershell
npm.cmd run setup:local
npm.cmd run db:migrate:local
npm.cmd run db:seed:local
npm.cmd run dev
```

## Work still outstanding

- Replace local symmetric JWTs with a real identity provider/JWKS flow; implement token revocation, key rotation, and production environments.
- Add real evidence upload/storage with tenant isolation, then OCR/AI and fraud screening.
- Persist decision amount/reason and implement actual payment processing. The existing pay endpoint only changes state.
- Implement Withdrawn and scheduled Expired transitions, notifications, profile/consent/mandate logic, tenant administration, and a frontend.
- Decide separation of duties, appeal limits, tenant-facing claimant references, and the ADMIN scope.

## Merge notes

The upstream branch moved the backend from `backend/` to the repository root and introduced MVC/OpenAPI files. The Phase 1 Worker was moved to root and retained as the active application. The newer `src/controllers/`, `src/routes/`, and `src/services/` files remain in the repository but are not mounted by `src/index.ts`; integrate them deliberately rather than enabling their stub endpoints without Phase 1 authorization.

Inherited README and security-document path references that said `backend/...` were rewritten to root-level paths on 2026-09-26 (docs cleanup commit on `main`).

## Prompt for the next agent

```text
Open docs/PHASE_01_HANDOFF.md first. Continue EasyClaim from commit da07e7c on main. Preserve the active Phase 1 Worker security model in src/index.ts and src/security/. First fix stale backend/ path references in the documentation and assess how to integrate the retained MVC/OpenAPI modules without exposing unauthenticated stub endpoints. Run npm.cmd run typecheck and npm.cmd test after every meaningful change. Do not add real secrets to the repository.
```
