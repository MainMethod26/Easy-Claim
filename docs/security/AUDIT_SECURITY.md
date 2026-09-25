# Audit Security

## Two separate streams

| Stream | Mechanism | Purpose | Trust |
|---|---|---|---|
| Application logs | `console.log` / `console.error` (Workers logs) | Debugging, queue processing, unhandled errors (`src/index.ts` `onError` logs with request id) | Operational only; not a security record |
| Security audit events | Rows in D1 table `audit_events` via `writeAuditEvent()` in `backend/src/security/audit.ts` | Who did what to which resource, and whether it was allowed | Append-only at DB layer; queryable per resource |

## Schema (`backend/migrations/0002_security.sql`)

| Column | Notes |
|---|---|
| `id` | `crypto.randomUUID()` |
| `occurred_at` | ISO timestamp, server clock |
| `actor_id`, `actor_role` | From `c.var.actor` (currently the dev stub — see README warning) |
| `action` | Dotted event name (below) |
| `resource_type`, `resource_id` | e.g. `claim` / `claim_disc_101` |
| `outcome` | `CHECK IN ('success','denied','failure')` |
| `request_id` | From Hono `requestId()` middleware; also returned as `X-Request-Id` |
| `details` | Small JSON of identifiers/state names only |

Append-only enforcement: triggers `audit_events_no_update` and `audit_events_no_delete` raise `audit_events is append-only`. No route updates or deletes audit rows. **TESTED/PASSED** (`test/audit.test.ts` → "audit rows cannot be updated or deleted").

## Events emitted today

| Action | Outcome | Emitted in |
|---|---|---|
| `claim.created` | success | `src/endpoints/claims.ts` POST `/initiate` |
| `claim.initiate_rejected` | denied | `src/endpoints/claims.ts` POST `/initiate` (policy not owned / not Active) |
| `claim.screening_updated` | success | `src/endpoints/claims.ts` PATCH `/:claimId/screening` |
| `claim.evidence_queued` | success | `src/endpoints/claims.ts` POST `/:claimId/evidence-ocr` |
| `claim.stage_changed` | success | `src/security/claimAccess.ts` `transitionClaim()` (details: `from`, `to`) |
| `claim.transition_rejected` | denied | `src/security/claimAccess.ts` `transitionClaim()` (details: `from`, `to`, `reason`) |
| `authz.claim_access_denied` | denied | `src/security/claimAccess.ts` `loadAuthorizedClaim()` (details: `mode`, `exists`) |
| `authz.role_denied` | denied | `src/security/rbac.ts` `requireRole()` |
| `cover.join_requested` | success | `src/endpoints/policy.ts` POST `/join-request` |
| `mandate.cancel_requested` | success | `src/endpoints/identity.ts` POST `/mandates/cancel` |

`GET /claims/:claimId/timeline` reads `claim.stage_changed` rows to build stage dates.

## Must never be logged (audit or app logs)

- Tokens, session IDs, `Authorization` headers, `X-Dev-Actor-*` headers, `.dev.vars` values, `JWT_SECRET` or any secret
- Free-text claim narratives (`causeOfLoss`), medical details, SA ID numbers, banking details, document contents / OCR text
- Full request bodies

Verified: `test/audit.test.ts` → "audit rows do not contain free-text claim narratives or headers" — TESTED/PASSED.

## Gaps

| Gap | Status |
|---|---|
| Login / failed-login / logout events | NOT IMPLEMENTED — no authentication exists yet (backend team) |
| Retention policy (POPIA) | NOT IMPLEMENTED |
| Export / SIEM / alerting on `denied` spikes | NOT IMPLEMENTED |
| Triggers can be dropped by anyone with D1 admin access (`wrangler d1 execute`) | Accepted risk; mitigate with restricted Cloudflare account access and periodic export |
| Audit write is not atomic with the state update in `transitionClaim()` (UPDATE then INSERT) | PARTIAL — handoff BACKEND-SEC-013 (use `DB.batch`) |
| Events for decision, payout, role change, config change | NOT IMPLEMENTED — those features do not exist |
| No read endpoint for auditors (`/activities/audit-trail` is a stub returning `[]`) | NOT IMPLEMENTED |
