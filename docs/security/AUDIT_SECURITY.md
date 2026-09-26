# Audit Security

## Two separate streams

| Stream | Mechanism | Purpose | Trust |
|---|---|---|---|
| Application logs | `console.log` / `console.error` (Workers logs) | Debugging, queue processing, unhandled errors (`src/index.ts` `onError` logs with request id) | Operational only; not a security record |
| Security audit events | Rows in D1 table `audit_events` via `writeAuditEvent()` in `src/security/audit.ts` | Who did what to which resource, and whether it was allowed | Append-only at DB layer; queryable per resource |

## Schema (`migrations/0002_security.sql`, column added by `0003_tenants.sql`)

| Column | Notes |
|---|---|
| `id` | `crypto.randomUUID()` |
| `occurred_at` | ISO timestamp, server clock |
| `actor_id`, `actor_role` | From `c.var.actor`. **Phase 1 update:** the actor now comes from a verified HS256 bearer JWT (`sub`, `role`; `src/security/actor.ts`). The Phase 0 dev-header stub is removed. |
| `actor_tenant_id` | **Phase 1 (new, `0003_tenants.sql`):** the acting insurer tenant from the token's `tenant_id`; `NULL` for customers (platform-level) and for ADMIN tokens without a tenant. Written by `auditStatement()` on every row. For a denial it names the *actor's* tenant only, never the target claim's tenant or owner (TESTED/PASSED: `test/tenant.test.ts` TENANT-001 asserts the row contains neither `ins_discovery` nor `user123`). |
| `action` | Dotted event name (below) |
| `resource_type`, `resource_id` | e.g. `claim` / `claim_disc_101` |
| `outcome` | `CHECK IN ('success','denied','failure')` |
| `request_id` | **Phase 1 update:** generated server-side in `src/index.ts` (`crypto.randomUUID()` per request, set as `c.var.requestId` and returned as `X-Request-Id`). It is never taken from an inbound header, because it is the correlation key persisted in the append-only trail. The Phase 0 Hono `requestId()` middleware is no longer used. |
| `details` | Small JSON of identifiers/state names only |

Append-only enforcement: triggers `audit_events_no_update` and `audit_events_no_delete` raise `audit_events is append-only`. No route updates or deletes audit rows. **TESTED/PASSED** (`test/audit.test.ts` → "audit rows cannot be updated or deleted").

### Phase 1 update: `changes()`-gated INSERT (atomic with the state change)

`auditStatement(c, event, { onlyIfPreviousChanged: true })` in `src/security/audit.ts` builds

```sql
INSERT INTO audit_events (...) SELECT ?, ?, ... WHERE changes() = 1
```

`transitionClaim()` (`src/security/claimAccess.ts`) runs this statement in **one `DB.batch`** immediately after the conditional `UPDATE claims ... WHERE id = ? AND stage = ?`. SQLite's `changes()` is the row count of the previous statement in the same connection, so the `claim.stage_changed` row is written only when the stage change applied, and both land or neither does (a D1 batch is a transaction). A 0-row UPDATE is then recorded separately as `claim.transition_rejected` with reason `stale_state`. **TESTED/PASSED** (`test/audit.test.ts` → "a stage-change audit row is written only when the stage change applied (same transaction)"). This closes the Phase 0 gap BACKEND-SEC-013. Denial rows written by `writeAuditEvent()` are single-statement inserts and do not need the gate.

### Phase 1 update: nothing is audited for unauthenticated requests

`requireActor` returns 401 `{"error":"unauthenticated"}` (with `WWW-Authenticate: Bearer`) before any database access, so there is no `audit_events` row for a missing, malformed, forged, expired or over-TTL token. The only trace is an application log line containing the request id and either the hono error class name (e.g. `JwtTokenSignatureMismatched`) or a fixed reason token (`claims:ttl_exceeded`), never the token or its claims. **TESTED/PASSED** (`test/auth.test.ts` AUTH-013 "server logs never contain the token", AUTH-014 "no audit row is written for unauthenticated requests"). Consequence: brute-force or token-forgery attempts are visible in Workers logs only, not in the audit table (see Gaps).

## Events emitted today

| Action | Outcome | Emitted in |
|---|---|---|
| `claim.created` | success | `src/endpoints/claims.ts` POST `/initiate` (details: `policyId`, **Phase 1:** `tenantId` copied from the policy) |
| `claim.initiate_rejected` | denied | `src/endpoints/claims.ts` POST `/initiate` (details `reason`: `policy_not_owned`, `policy_not_active`, **Phase 1:** `policy_missing_tenant`) |
| `claim.screening_updated` | success | `src/endpoints/claims.ts` PATCH `/:claimId/screening` |
| `claim.evidence_queued` | success | `src/endpoints/claims.ts` POST `/:claimId/evidence-ocr` |
| `claim.stage_changed` | success | `src/security/claimAccess.ts` `transitionClaim()` (details: `from`, `to`; **Phase 1:** plus `outcome` = `Approved`/`Rejected` when written by POST `/:claimId/decide`). Written by the `changes()`-gated INSERT in the same batch as the UPDATE. |
| `claim.transition_rejected` | denied | `src/security/claimAccess.ts` `transitionClaim()` (details: `from`, `to`, `reason`). **Phase 1 reasons:** `unknown_stage`, `illegal_transition`, `role_not_permitted` (from `checkTransition`); `stale_state` (conditional UPDATE changed 0 rows); `not_approved` (emitted by `src/endpoints/claimsInsurer.ts` POST `/:claimId/pay` when the claim is in `Decision` but `status` is not `Approved`) |
| `authz.claim_access_denied` | denied | `src/security/claimAccess.ts` `loadAuthorizedClaim()` (details: `mode` = `read`/`owner-write`/`insurer`, `exists`, **Phase 1:** `reason`). **Reasons:** `missing` (no such claim), `not_owner` (customer, not their claim), `role` (ADMIN or other non-insurer role), `tenant_unset` (claim has `tenant_id NULL`; visible to no insurer, fail closed), `cross_tenant` (insurer of another tenant), `draft` (insurer of the right tenant, claim not yet submitted), `mode` (defensive fallback: the actor could read the claim but the route's mode excludes them; not reachable through current routes because the coarse `requireRole` gates run first). Also emitted by `transitionClaim()` with `{ mode: 'transition', exists: true, reason: 'transition_guard' }` when its owner/tenant re-check fails (defence in depth; 403). The client always sees 404 `not_found` from `loadAuthorizedClaim`, so existence is not leaked across tenants or customers (TESTED/PASSED TENANT-003b). |
| `authz.role_denied` | denied | `src/security/rbac.ts` `requireRole()` (resource `route` / `"<METHOD> <routePath>"`). **Phase 1:** also written by `src/endpoints/claims.ts` GET `/` (resource `route` / `"GET /claims"`) when an ADMIN calls the list endpoint (403; TESTED/PASSED TENANT-006). The code's other fall-through, an insurer token without `tenant_id`, cannot occur because `validateClaims` rejects such tokens with 401 (`staff_without_tenant`). |
| `cover.join_requested` | success | `src/endpoints/policy.ts` POST `/join-request` |
| `mandate.cancel_requested` | success | `src/endpoints/identity.ts` POST `/mandates/cancel` |

`GET /claims/:claimId/timeline` reads `claim.stage_changed` rows to build stage dates. **Phase 1 update:** a main-path stage is marked `completed` when the audit trail shows it was reached **or** the claim is currently at or beyond it on the main path (seeded claims have no audit history); `date` is only set from the audit trail.

There is still no `claim.decision_recorded`, `payout.*`, `auth.*`, role-change or config-change event (see Gaps). A decision is visible as `claim.stage_changed { to: 'Decision', outcome }` and a payout transition as `claim.stage_changed { to: 'Paid' }`.

Live counts per action/role/tenant for one wrangler-dev run (ATTACK-P1-001 to -010, the supplementary -004d / -011 / -012 checks, and the happy path) are in `docs/phase-reports/evidence/PHASE_01_LIVE_ATTACKS.log` ("Audit rows for this run").

## Must never be logged (audit or app logs)

- Tokens, session IDs, `Authorization` headers, `X-Dev-Actor-*` headers (Phase 1: retired and ignored, still never logged), `.dev.vars` values, `JWT_SECRET` or any secret
- **Phase 1:** decoded JWT claims or hono `Jwt*` error *messages* (they embed the raw token). Only the error class name (`err.name`) or a fixed `claims:<reason>` token is logged (`src/security/actor.ts`).
- Free-text claim narratives (`causeOfLoss`), appeal `reason` text, medical details, SA ID numbers, banking details, document contents / OCR text
- Another tenant's identifiers in a denial row (the row names the actor's own `actor_tenant_id` only)
- Full request bodies

Verified: `test/audit.test.ts` → "audit rows do not contain free-text claim narratives, headers or tokens" (asserts no `Hospital admission`, `X-Dev-Actor`, `Bearer` or `eyJ` in any row) — TESTED/PASSED. `test/auth.test.ts` AUTH-013 → server logs never contain the token — TESTED/PASSED.

## Gaps

| Gap | Status |
|---|---|
| Login / failed-login / logout events | NOT IMPLEMENTED. **Phase 1 update:** authentication now exists (bearer JWT), but by design no audit row is written before a token is verified (AUTH-014), and there is no login/logout endpoint: tokens are minted outside the API (`npm run token` locally; an identity provider is PLANNED). Failed verifications appear only as Workers log lines with the request id and error class. Alerting on those lines is NOT IMPLEMENTED. |
| Retention policy (POPIA) | NOT IMPLEMENTED — rows accumulate indefinitely; no purge, no archive |
| Export / SIEM / alerting on `denied` spikes | NOT IMPLEMENTED |
| Triggers can be dropped by anyone with D1 admin access (`wrangler d1 execute`) | Accepted risk, still open in Phase 1; mitigate with restricted Cloudflare account access and periodic export |
| Audit write is not atomic with the state update in `transitionClaim()` (UPDATE then INSERT) | **IMPLEMENTED in Phase 1** — one `DB.batch` with a `changes()`-gated INSERT (see above); TESTED/PASSED. BACKEND-SEC-013 closed. |
| Events for decision, payout, role change, config change | PARTIAL — decision and payout **transitions** are audited as `claim.stage_changed` (with `outcome` for decisions) and their denials as `claim.transition_rejected`; there is no separate decision record or payout event because no amount, reason or payment exists (PLANNED, see DECISION_SECURITY.md / PAYOUT_SECURITY.md). Role change and config change events NOT IMPLEMENTED (no such features). |
| No read endpoint for auditors (`GET /activities/audit-trail` is a stub returning `{ trail: [] }`) | NOT IMPLEMENTED — unchanged (`src/endpoints/audit.ts`; it does not read `audit_events`). A future read endpoint must be tenant-scoped on `actor_tenant_id` / claim tenant. |
| Tenant scoping of the audit table itself | NOT IMPLEMENTED — `audit_events` is one table for all tenants; `actor_tenant_id` records who acted, but rows are not filtered per tenant anywhere yet because nothing reads them except the timeline (which is already claim-scoped through `loadAuthorizedClaim`). |
| Rate-limit (429) events | NOT IMPLEMENTED — the per-IP and per-actor limiters in `src/index.ts` return 429 without an audit row |
