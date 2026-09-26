# Backend Security Handoff

**Question answered:** What does the backend team need to implement so the cyber team can test and verify the system?

> **Phase 1 update (2026-09-26).** Authentication (BACKEND-SEC-001), tenant scoping (002), insurer
> workflow endpoints (003), per-actor rate limits (012) and atomic audit writes (013) are now
> IMPLEMENTED on branch `cyber`. Their entries below keep the original wording with a status change
> so the history stays traceable. New items 015–020 are the Phase 1 handoff. Phase 1 details:
> `docs/phase-reports/PHASE_01_REPORT.md`.

## Already delivered by cyber (branch `cyber`)

| Module | What it gives you |
|---|---|
| `src/types.ts` | `Role`, `Actor { id, role, tenantId }`, `ID_PATTERN`, `Bindings` (incl. `JWT_SECRET`, `JWT_ISSUER`, `JWT_AUDIENCE`), `AppEnv` |
| `src/security/actor.ts` | `requireActor` middleware; `resolveActor()` verifies `Authorization: Bearer <JWT>` (HS256 pinned, iss/aud/exp/iat, bounded TTL); `validateClaims()` role/tenant rules. Swap point for an IdP: `hono/jwt` `verifyWithJwks` |
| `src/security/rbac.ts` | `requireRole(...roles)` (resource-independent gate, audited) |
| `src/security/claimAccess.ts` | `loadAuthorizedClaim(c, id, 'read' \| 'owner-write' \| 'insurer')` with tenant boundary, `isTenantInsurer()`, `transitionClaim(c, claim, to, { status?, details? })` (owner/tenant guard, state machine, one D1 batch: conditional UPDATE + audit INSERT gated on `changes() = 1`) |
| `src/security/claimStateMachine.ts` | `TRANSITIONS`, `checkTransition()` (unchanged in Phase 1) |
| `src/security/audit.ts` | `writeAuditEvent(c, event)`, `auditStatement(c, event, { onlyIfPreviousChanged })`; rows carry `actor_tenant_id` and a server-generated `request_id` |
| `src/security/validation.ts` | strict zod schemas (`decideSchema`, `listQuerySchema`, …) + `validate('json' \| 'param' \| 'query', schema)` |
| `src/endpoints/claimsInsurer.ts` | `POST /claims/:claimId/verify`, `/screen`, `/review`, `/request-info`, `/decide`, `/pay` — thin wrappers over `transitionClaim()` |
| `src/endpoints/claims.ts` | `GET /claims` (owner / tenant scoped, no drafts and no `user_id` for insurers) |
| `migrations/0002_security.sql`, `0003_tenants.sql` | claim columns, `audit_events` (append-only), `evidence` table (unused), `tenants`, `policies.tenant_id`, `claims.tenant_id`, `audit_events.actor_tenant_id` |
| `scripts/mint-token.mjs`, `setup-dev-vars.mjs` | local tokens (`npm run token -- --demo \| --postman`), local secret setup (`npm run setup:local`) |
| `test/*.test.ts` | 232 tests, 15 files after Phases 2–4 and the evidence-binding follow-up (`npm test`) |

## Requirements

### BACKEND-SEC-001 — Real authentication
- **Requirement (Phase 0):** Replace the body of `resolveActor()` in `src/security/actor.ts` with verified identity (e.g. `hono/jwt` HS256 with pinned `alg`, `JWT_SECRET` via `wrangler secret put`, required `sub`, `role`, `exp`; or a managed IdP). Return `null` on any failure.
- **Why:** Identity came from spoofable headers (OWASP API2).
- **Status:** IMPLEMENTED (Phase 1) as app-verified HS256 (`actor.ts`: pinned alg, required `iss`/`aud`/`exp`/`iat`, TTL cap 24 h customer / 8 h staff, role–tenant rules, no token in logs, no pre-auth DB writes). The dev header stub is removed. Identity-provider integration (asymmetric keys, JWKS) is PLANNED, see 019.
- **Acceptance:** met — `test/auth.test.ts` AUTH-001…014, `test/actor.test.ts`; live: `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` ATTACK-P1-001…004, 009, 010.

### BACKEND-SEC-002 — Tenant/org scoping for insurer roles
- **Requirement (Phase 0):** Add an organisation id to actor, policies, claims. In `loadAuthorizedClaim()`, insurer roles may only access claims of their organisation.
- **Status:** IMPLEMENTED (Phase 1) as `tenant_id` (`migrations/0003_tenants.sql`, `types.ts`, `claimAccess.ts` `isTenantInsurer()`). Claims with `tenant_id` NULL and unsubmitted Drafts are visible to no insurer.
- **Acceptance:** met — `test/tenant.test.ts` TENANT-001…007; live ATTACK-P1-005/006.
- **Still yours:** any new table that holds claim-related data must carry `tenant_id` and be read through the same check.

### BACKEND-SEC-003 — Insurer workflow endpoints through the state machine
- **Requirement (Phase 0):** New endpoints for verify, screen, info-needed, review, decide, pay MUST use `requireRole(...)`, `loadAuthorizedClaim(c, id, 'insurer')` and `transitionClaim()`. Never `UPDATE claims SET stage` directly.
- **Status:** IMPLEMENTED (Phase 1) in `src/endpoints/claimsInsurer.ts`. `transitionClaim()` now also refuses to move a claim the actor may not touch (owner / tenant guard), so a route that forgets `loadAuthorizedClaim` still cannot cross a tenant — but it would leak existence via 403 instead of 404, so keep calling `loadAuthorizedClaim` first.
- **Acceptance:** met — `test/tenant.test.ts` STATE-001…006; live happy path and ATTACK-P1-007/008.

### BACKEND-SEC-004 — Strict schemas on every new endpoint
- **Requirement:** Use `validate('json', z.object({...}).strict())` from `validation.ts`; never spread request bodies into DB writes; set `user_id`, `tenant_id`, `stage`, `status`, decision/payout fields server-side only.
- **Status:** IMPLEMENTED for all existing routes (incl. `tenant_id`/`tenantId` rejected, `test/massAssignment.test.ts`).
- **Acceptance:** extend `test/massAssignment.test.ts` for each new route.

### BACKEND-SEC-005 — Decision record
- **Requirement:** Table `claim_decisions` (claim_id, tenant_id, outcome, amount, reason, actor_id, actor_role, decided_at, request_id, rules_version, model_version, evidence hashes, screening result), insert-only with the same trigger pair as `audit_events`, written in the same `DB.batch` as the `Review → Decision` transition (pass extra statements through `transitionClaim`). `GET /claims/:id/decision` reads it.
- **Status:** IMPLEMENTED (Phase 3) — `claim_decisions` insert-only table (`migrations/0005_decisions_payouts.sql`): outcome, reason, previous stage, claimed/approved amounts, destination snapshot, actor, role, time, request id, `rules_version`; written in the same D1 batch as the transition. Reserved columns `evidence_digest` (Phase 2), `risk_signal`, `integrity_signature` are NULL. Decision is now MANAGER-only. See `docs/phase-reports/PHASE_03_REPORT.md`.
- **DECISION REQUIRED:** may ASSESSORs decide, or MANAGER only? (state machine currently allows both for `Review → Decision`).

### BACKEND-SEC-006 — Payout protections
- **Requirement:** Payout only from Decision/Approved by MANAGER; idempotency key per claim; verified destination; step-up auth for destination changes; high-value threshold requires second approver; audit `payout.*` events.
- **Status:** PARTIAL (Phase 3) — simulated payout IMPLEMENTED: MANAGER-only, no client body, amount = recorded approved amount (≤ claimed), destination hash must match the decision snapshot, `payouts.claim_id UNIQUE` + `Idempotency-Key` replay, all denials audited (`payout.blocked`). Still yours: real payment rail, destination verification / step-up auth for legitimate destination changes, high-value second approver, separation of duties (015). See `docs/phase-reports/PHASE_03_REPORT.md`.

### BACKEND-SEC-007 — Evidence upload
- **Requirement:** R2 bucket binding; server-generated `storage_key`; size limit; MIME + magic-byte allowlist (PDF/JPEG/PNG); compute SHA-256 into `evidence.sha256`; row in existing `evidence` table linked to `claim_id`, `uploaded_by` and the claim's `tenant_id`; access only through `loadAuthorizedClaim` (owner or tenant insurer); no overwrite — new version instead; audit `evidence.uploaded`.
- **Status:** IMPLEMENTED (Phase 2) — `src/endpoints/evidence.ts`, `src/security/evidence.ts`, `migrations/0004_evidence_security.sql`. Upload/list/download/verify all go through `loadAuthorizedClaim`; SHA-256 integrity check (`GET .../verify` → `VALID`/`TAMPERED`) added beyond the original ask. Overwrite/replace is NOT IMPLEMENTED — evidence is immutable once uploaded instead (no route removes or replaces it), which also closes the "no metadata modification" requirement. TENANT-004 is covered by `test/evidence.test.ts` instead (15/15 passing); the `tenant.test.ts` `it.todo` itself was left as-is (not this phase's file to edit). See `docs/phase-reports/PHASE_02_REPORT.md`.
- **Deployment note for whoever runs `wrangler deploy` (this is infrastructure, not code — cyber is not touching Cloudflare):** the `[[r2_buckets]]` binding `EVIDENCE_BUCKET` is declared in `wrangler.toml` but the bucket only exists locally (Miniflare emulates it for `wrangler dev`/tests automatically). Before a real deploy: `wrangler r2 bucket create easy-claim-evidence`, then `wrangler d1 migrations apply easy-claim-db --remote` to pick up `migrations/0004_evidence_security.sql` alongside the others. Without the bucket, evidence routes fail closed with `503 {"error":"storage_unavailable"}` rather than erroring at boot.

### BACKEND-SEC-008 — OCR/AI output as untrusted signal
- **Requirement:** OCR/AI returns a zod-validated risk signal only; it must never call `transitionClaim()`. See `AI_SECURITY.md`.
- **Status:** NOT IMPLEMENTED (no OCR). Queue message validation IMPLEMENTED.

### BACKEND-SEC-009 — Configuration change audit
- **Requirement:** Fraud thresholds, payout limits, roles stored as versioned config; changes ADMIN-only with actor, old/new value, reason, version in `audit_events`.
- **Status:** NOT IMPLEMENTED (no config exists).

### BACKEND-SEC-010 — Replace stubs with actor-scoped data
- **Requirement:** `/profile/*`, `/client/*` (hardcoded alerts/activity), `/activities/*`, `/profile/mandates/:tenantId/check` must query data for `c.get('actor').id` only; `PATCH /profile` needs a strict schema. Note `:tenantId` on the mandate route now collides with the insurer-tenant vocabulary; rename or scope it.
- **Status:** stubs; behind `requireActor`.

### BACKEND-SEC-011 — Queue consumer in local dev
- **Requirement (Phase 0):** Investigate why `processQueueBatch` does not fire under `wrangler dev`.
- **Status:** RE-OBSERVED in Phase 1: the consumer DID fire during the live run (`OCR Service processing claim: …` in the dev-server log after a submit). The Phase 0 observation is therefore intermittent/timing-related, not a defect in the code path. Keep `test/queue.test.ts` as the authoritative check.

### BACKEND-SEC-012 — Rate limits per user
- **Status:** IMPLEMENTED (Phase 1): per-IP limiter before auth and per-actor limiter (`actor:<role>:<id>`) after auth on the same binding (`src/index.ts`). Stricter limits for upload/OCR routes remain PLANNED with those routes.

### BACKEND-SEC-013 — Atomic audit writes
- **Status:** IMPLEMENTED (Phase 1): `transitionClaim()` runs `UPDATE … WHERE stage = ?` and `INSERT INTO audit_events … WHERE changes() = 1` in one `DB.batch` (`test/audit.test.ts`).

### BACKEND-SEC-014 — Keep the tests green
- **Requirement:** `npm test`, `npm run typecheck`, `npm audit` pass on every PR; new sensitive routes ship with BOLA, RBAC, tenant and mass-assignment tests.
- **Status:** IMPLEMENTED locally (232 tests, 15 files); CI NOT IMPLEMENTED.

### BACKEND-SEC-015 — Separation of duties (DECISION REQUIRED)
- **Question:** may the MANAGER who recorded the decision also perform `/pay`, and may the original decider re-review an appeal? Today nothing prevents it.
- **If yes to separation:** with the decision record (005) in place, `/pay` and `Appeal → Review` return `409 separation_of_duties` when `decision.actor_id === actor.id`.

### BACKEND-SEC-016 — Appeal limit (DECISION REQUIRED)
- **Question:** how many times may a rejected claim be appealed? The cycle `Decision(Rejected) → Appeal → Review → Decision` is currently unbounded. Enforce by counting `claim.stage_changed` rows with `to = 'Appeal'` in `POST /appeal`, or add a terminal stage.

### BACKEND-SEC-017 — Claimant reference for insurers (DECISION REQUIRED)
- **Question:** `user_id` is a platform-wide identifier, so it is currently NOT returned to insurer staff (`GET /claims`). Decide on a per-tenant claimant reference (e.g. HMAC of `tenant_id:user_id`) or explicitly accept exposing `user_id`.

### BACKEND-SEC-018 — Per-environment configuration
- **Requirement:** `wrangler.toml` has one global `[vars]` block. Add `[env.production]` (own `JWT_ISSUER`, `JWT_AUDIENCE`, `ALLOWED_ORIGINS`, real `database_id`, queue and ratelimit bindings) and set `JWT_SECRET` with `wrangler secret put JWT_SECRET --env production`. Never reuse the local secret.
- **Status:** NOT IMPLEMENTED.

### BACKEND-SEC-019 — Identity provider, key rotation, revocation
- **Requirement:** Move token issuance to an IdP or auth service; switch `resolveActor()` to `verifyWithJwks` (asymmetric, `kid` rotation); add a `jti` denylist (KV) or shorter TTLs if revocation is required. Until then secret rotation + bounded TTL (24 h / 8 h) are the compensating controls.
- **Status:** PLANNED.

### BACKEND-SEC-020 — ADMIN scope (DECISION REQUIRED)
- **Question:** is ADMIN platform-wide or per tenant? Tokens may carry `tenant_id` for ADMIN but it is ignored; ADMIN has no claim access at all today. Decide before building admin/configuration endpoints (009).

### BACKEND-SEC-021 — Unmounted MVC layer must stay unmounted until it is guarded (added 2026-09-26, Phase 4 merge)

`src/controllers/*`, `src/routes/*`, `src/services/*` are present in the repository but are **not** mounted by `src/index.ts`. Upstream commit `d76a0c6` mounted them in place of the secured entry point; the Phase 4 rebase restored the secured entry point (see `docs/quantum/PHASE_04_REPORT.md` §18a). An automated security review of those unmounted files found, in addition to the missing `requireActor`:

| # | File | Finding | Severity if mounted |
|---|---|---|---|
| 1 | `src/controllers/claimsController.ts` | `verify`, `screening`, `pay` and the other stage handlers call `ClaimsService.updateStage` with no actor, no ownership/tenant check, no state-machine check, and are reachable by GET | CRITICAL |
| 2 | `src/controllers/claimsController.ts` | `initiate` takes `policyId` from the body without verifying the policy belongs to the caller | HIGH |
| 3 | `src/controllers/identityController.ts` | identity is read from the client header `x-user-id` with a default of `user123` | HIGH |
| 4 | `src/controllers/policyController.ts` | `saveRequirements` inserts against a client-supplied `policyId` with no ownership check | HIGH |

Status: NOT EXPLOITABLE today (not mounted). Required before any of these routes are mounted: go through `requireActor`, `requireRole`, `loadAuthorizedClaim` and `transitionClaim` exactly like `src/endpoints/*`, or delete the layer. Owner: backend team. Rule recorded in `docs/PARALLEL_WORK.md` (`src/index.ts`: append mounts only, keep `requireActor` on `/api/v1/*`).
