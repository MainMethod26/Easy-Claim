# Threat Model

Scope: the Cloudflare Worker at the repository root (Hono), D1 database `DB`, Queue `CLAIM_EVENTS`. The Flutter mobile app under `lib/` is a separate client and is out of scope for this threat model; it must be treated as an untrusted caller of the API.

## Assets

| Asset | Where | Sensitivity |
|---|---|---|
| Claims (owner, policy, tenant, stage, status, cause of loss, incident date) | D1 `claims` (`tenant_id` added in Phase 1) | High: health, vehicle and life incidents (POPIA special personal information) |
| Policies | D1 `policies` (`tenant_id` added in Phase 1) | Medium–High |
| Tenants (insurer organisations) and the tenant boundary (Phase 1) | D1 `tenants`, `policies.tenant_id`, `claims.tenant_id`, `audit_events.actor_tenant_id` (`migrations/0003_tenants.sql`) | High: one insurer's staff must never see or move another insurer's claims |
| Audit trail | D1 `audit_events` | High (integrity) |
| Evidence metadata (future) | D1 `evidence` (table exists, unused) | High |
| Claim decision and payout | `claims.status` (`Approved` / `Rejected`) and stage `Paid` written by `POST /claims/:claimId/decide` / `/pay` (Phase 1: state transitions only; no decision record, no payment execution) | Critical (money) |
| Debit-order mandates (future) | `/profile/mandates/*` stubs | High (money) |
| Signing secret `JWT_SECRET` (Phase 1) | Worker secret binding (`wrangler secret put JWT_SECRET`); `.dev.vars` locally (gitignored) | Critical: whoever holds it can mint a token for any role and any tenant. No rotation procedure (NOT IMPLEMENTED) |
| Bearer tokens (Phase 1) | Client side; `Authorization` header in transit | High: a stolen token is usable until `exp` (≤ 24 h customer, ≤ 8 h staff); no revocation (PLANNED) |
| Configuration: CORS origins, rate limits, `JWT_ISSUER` / `JWT_AUDIENCE` | `wrangler.toml` `[vars]`, `.dev.vars` | High (the Phase 0 dev auth flag no longer exists) |

## Actors

| Actor | Capability | Goal |
|---|---|---|
| Token-bearing customer (`CUSTOMER`; token without `tenant_id`) | Own claims and policies across several insurers (platform-level); list own claims | Legitimate use. May also inflate or fake a claim |
| Tenant staff (`ASSESSOR` / `MANAGER`; token with `tenant_id`) — Phase 1 | Read and transition the non-Draft claims of their own tenant only: verify, screen, review, request-info, decide; MANAGER additionally pay and appeal re-review | Legitimate use; insider fraud risk (the same manager may decide and pay: DECISION REQUIRED) |
| Admin (`ADMIN`; `tenant_id` optional) | No claim access and no transitions today (list → 403; read routes `timeline` / `decision` → 404 reason `role`; every role-gated route → 403 from `requireRole`). Configuration and users are future | Misconfiguration or abuse; platform vs tenant admin scope DECISION REQUIRED |
| External attacker without a token | Unauthenticated HTTP | 401 on every `/api/v1/*` route; abuse, denial of service (per-IP rate limit) |
| Attacker with a forged or tampered token (Phase 1) | Signs with another secret, edits the payload, uses `alg=none` or HS512, exceeds the TTL cap | Impersonation or role escalation → rejected 401 (`auth.test.ts` AUTH-003/004/004b/004c/004d/006c; live ATTACK-P1-001..004d) |
| Attacker with a stolen valid token (Phase 1) | Replays a genuine token from another device until `exp` | Acts as that actor for up to 24 h (customer) / 8 h (staff). No revocation exists (residual risk) |
| Cross-tenant insider (Phase 1) | Valid staff token for tenant B | Read or transition tenant A claims → 404 identical to a missing claim, audited `cross_tenant` (`tenant.test.ts` TENANT-001..003b; live ATTACK-P1-005/006) |
| Same-tenant compromised insider | Valid staff token for the claim's own tenant | Approve or pay fraudulent claims inside the tenant; bounded only by the per-transition role (pay is MANAGER-only) and the audit trail |
| Holder of `JWT_SECRET` / the token issuer (Phase 1) | Can mint any `sub`, `role`, `tenant_id` | Total impersonation; the only controls are secret handling (secret binding, ≥ 32 bytes) and rotation (NOT IMPLEMENTED) |
| Malicious document | Uploaded evidence (future) | Exploit parsers, inject prompts into AI/OCR |

## Trust boundaries

1. **Client → Worker** (`/api/v1/*`): all input is untrusted. Controls (Phase 1 update): bearer token verification (`requireActor` → `resolveActor` in `src/security/actor.ts`), zod validation, body limit, per-IP rate limit before authentication and per-actor rate limit after it, CORS allowlist. Identity, role and tenant are taken only from the verified token, never from headers, bodies or query strings.
2. **Token issuer → Worker** (Phase 1, NEW): the Worker trusts any token whose HS256 signature verifies with `JWT_SECRET`, whose `iss` equals `JWT_ISSUER`, whose `aud` equals or contains `JWT_AUDIENCE` (an array audience is accepted, `auth.test.ts` AUTH-007), and whose claims pass `validateClaims` (`exp` + `iat` required, per-role TTL cap, `sub` / `tenant_id` format, role-dependent `tenant_id` rule). Today the only issuer is `scripts/mint-token.mjs` (local demos); there is no identity provider, user store or revocation list. The boundary *is* the shared secret: it is a Worker secret binding and never in `wrangler.toml`. Missing configuration fails closed (every request 401). PLANNED: external IdP via `hono/jwt` `verifyWithJwks` (asymmetric keys), key rotation, `jti` denylist.
3. **Worker → D1**: parameterised queries only. The audit table has triggers that block UPDATE/DELETE. Phase 1: `claims.tenant_id` / `policies.tenant_id` reference `tenants`; the tenant boundary is enforced in the Worker (`claimAccess.ts`), not by the database.
4. **Worker → Queue producer**: only server-built payloads are sent (`claims.ts` submit and evidence-ocr).
5. **Queue → consumer** (`ocr.ts` `processQueueBatch`): messages are re-validated with zod; malformed ones are acked and dropped.
6. **Future OCR/AI**: output is an untrusted signal and never a decision (AI_SECURITY.md).
7. **Future object storage (R2)**: private bucket, server-generated keys (EVIDENCE_SECURITY.md).

## STRIDE per component

| Component | S | T | R | I | D | E |
|---|---|---|---|---|---|---|
| Authentication / token verification (`src/security/actor.ts`) — Phase 1 update (Phase 0: dev headers spoofable when the flag was on) | Forged, tampered, `alg=none`, HS512, expired and over-TTL tokens → 401 (TESTED/PASSED AUTH-003..006c; live ATTACK-P1-001..004d, 009). **Residual:** a stolen valid token works until `exp`; anyone holding `JWT_SECRET` can mint any identity | Signature covers header and payload; claims are re-validated after `verify` (`validateClaims`) | Verified `sub`, `role` and `tenant_id` are written to every audit row (`actor_id`, `actor_role`, `actor_tenant_id`) with the server-generated `request_id`; nothing is audited pre-auth | 401 body is fixed (`{"error":"unauthenticated"}`); logs carry only the hono error class name or a fixed reason token, never the token (AUTH-012/013) | Per-IP limit runs before verification; verification is one HMAC; missing config fails closed rather than open | Role and tenant come from signed claims only; TTL capped per role (24 h / 8 h); retired dev headers are ignored even next to a valid token (AUTH-011, ATTACK-P1-010) |
| Tenant isolation (`src/security/claimAccess.ts`, `migrations/0003_tenants.sql`) — Phase 1 NEW | Tenant is the token claim, not a request field; a customer token may not carry one | `tenant_id` set server-side from the policy on initiate, never from the client; strict schemas reject `tenantId` | Every denial audited `authz.claim_access_denied` {mode, exists, reason} with the actor's tenant (details name only the actor's own context, never the claim's tenant or owner) | Cross-tenant, Draft and tenant-less claims → 404 identical to a missing claim (TENANT-003b; live ATTACK-P1-005); insurer list omits `user_id` | `?limit` bounded 1..50 | `isTenantInsurer` checked in `loadAuthorizedClaim` and again in `transitionClaim` (`transition_guard`). **Residual:** ADMIN `tenant_id` optional and not used for authorization, only recorded in audit rows (DECISION REQUIRED); evidence isolation BLOCKED |
| Claim routes (`src/endpoints/claims.ts`) | Depends on token verification | Mass assignment blocked (strict schemas); screening stage precondition repeated in SQL | Audit on create, screening, evidence, transitions, denials | IDOR blocked (404, no existence oracle; live ATTACK-P1-011); `GET /claims` scoped per owner / per tenant | Body limit, per-IP and per-actor rate limit | State machine blocks illegal jumps; customer can't decide or pay (403 from the coarse gate, live ATTACK-P1-007) |
| Insurer routes (`src/endpoints/claimsInsurer.ts`) — Phase 1 NEW | Depends on token verification | Strict `decideSchema`; stage and status written only by `transitionClaim`'s conditional UPDATE; replay → 409 (live "pay again") | Every transition, rejection (`not_approved`, `illegal_transition`, `role_not_permitted`, `stale_state`) and denial audited with the actor tenant | `requireRole` runs before any claim lookup, so a 403 carries no claim data | — | Per-transition role from `TRANSITIONS` (pay and appeal re-review MANAGER-only; live ATTACK-P1-008). **Residual:** same manager may decide and pay (DECISION REQUIRED); `/pay` executes no payment |
| Policy routes (`src/endpoints/policy.ts`) | Depends on token verification | `join-request` strict | Audited | `my-covers` scoped to the actor | Rate limit | CUSTOMER only |
| OCR route + consumer (`src/endpoints/ocr.ts`) | — | Queue payload validated | Console logs only | — | Malformed messages acked (no infinite retry); consumer not observed under `wrangler dev` | `/ocr/process` limited to ASSESSOR/MANAGER; no resource, so no tenant check yet |
| Profile/mandates (`src/endpoints/identity.ts`) | Depends on token verification | PATCH profile is a no-op stub | Mandate cancel audited | Stubs return empty data | Rate limit | Mandate cancel is CUSTOMER only; `:tenantId` path param is ignored and unrelated to the token tenant |
| D1 audit table | — | UPDATE/DELETE blocked by triggers; stage change and its audit row written in one batch (`INSERT ... WHERE changes() = 1`) | This is the repudiation control; now includes `actor_tenant_id` and `request_id` | No narratives, PII or tokens stored (`audit.test.ts`) | — | A DB admin can still drop triggers (out of app scope, open since Phase 0) |
| Config and secrets (`wrangler.toml`, `.dev.vars`, Worker secrets) | — | Deploy-time only, no runtime config API | Git history only | `JWT_SECRET` is a secret binding, never in the repo; `.dev.vars` and the Postman environment are gitignored | — | Phase 0 dev flag removed. **Residual:** a leaked `JWT_SECRET` = mint any role/tenant; a short secret is refused (< 32 bytes → all 401); no `[env.production]` split, so `JWT_ISSUER` = `easyclaim-dev` everywhere until changed (NOT IMPLEMENTED) |

## Residual risks after Phase 1 (authentication and tenant isolation)

| Risk | Why it remains | Status |
|---|---|---|
| No token revocation / `jti` denylist | A stolen or leaked token is valid until `exp` (≤ 24 h customer, ≤ 8 h staff). The only compensating controls are the per-role TTL cap and rotating `JWT_SECRET`, which invalidates every token at once | PLANNED |
| Shared-secret HS256 | Issuer and verifier share one key, so anyone who can read the Worker secret or a developer's `.dev.vars` can mint a token for any role and tenant. Asymmetric keys via `verifyWithJwks` are documented, not implemented | PLANNED |
| Clock skew | `validateClaims` rejects `exp <= now` with no leeway, and `hono/jwt` rejects `iat` / `nbf` in the future, so an issuer clock ahead of the Worker produces spurious 401s (the local mint script backdates `iat` by 60 s for this reason). No leeway setting exists | PARTIAL (documented, not configurable) |
| ADMIN scope | `tenant_id` is optional in an ADMIN token and is not used in any authorization decision (only written to `audit_events.actor_tenant_id`); ADMIN has no functions today, so a leaked ADMIN token grants nothing now, but platform vs tenant admin is undecided | DECISION REQUIRED |
| Separation of duties | The same MANAGER may decide and then pay; no decider/payer identity check and no "not the original decider" check on appeal re-review | DECISION REQUIRED |
| Key rotation | No procedure or dual-key window; rotating the secret logs everyone out | NOT IMPLEMENTED |
| Per-environment configuration | Single `wrangler.toml`; no `[env.production]`; `JWT_ISSUER` / `JWT_AUDIENCE` must be changed by hand per environment | NOT IMPLEMENTED |
| Evidence tenant isolation | No evidence endpoint or storage exists, so the tenant boundary cannot be applied to evidence (`TENANT-004` todo) | BLOCKED |

## Top risks tied to actual endpoints

| # | Risk | Endpoint(s) | Status |
|---|---|---|---|
| 1 | No real authentication | all `/api/v1/*` | Phase 0: NOT IMPLEMENTED (dev stub) → Phase 1: IMPLEMENTED, TESTED/PASSED — application-verified HS256 Bearer JWT (`src/security/actor.ts`; `test/auth.test.ts`; live ATTACK-P1-001..004d, 009, 010). Residual: no revocation, shared secret (rows 9–10) |
| 2 | Insurer staff can read every claim (no org scope) | `GET /claims`, `GET /claims/:claimId/timeline`, `/decision`, all insurer routes | Phase 0: NOT IMPLEMENTED → Phase 1: IMPLEMENTED, TESTED/PASSED — tenant isolation in `src/security/claimAccess.ts` + `migrations/0003_tenants.sql` (`test/tenant.test.ts` TENANT-001..007; live ATTACK-P1-005/006/012) |
| 3 | No insurer workflow endpoints, so verify/screen/decide/pay can't be driven or tested over HTTP | `POST /claims/:claimId/verify`, `/screen`, `/review`, `/request-info`, `/decide`, `/pay` (`src/endpoints/claimsInsurer.ts`) | Phase 0: PLANNED → Phase 1: IMPLEMENTED, TESTED/PASSED as state transitions (STATE-001..006; live Submitted → Paid path). `Withdrawn` still has no endpoint and `Expired` no job (PLANNED) |
| 4 | Payout and mandates are stubs, so the money path has no controls | `POST /claims/:claimId/pay` (transition only), `/profile/mandates/*` | PARTIAL: `/pay` is MANAGER-only, requires status `Approved`, is replay-safe and audited, but executes no payment and has no dual control; mandates remain stubs (NOT IMPLEMENTED) |
| 5 | Evidence upload doesn't exist; the endpoint only queues an event | `POST /claims/:claimId/evidence-ocr` | NOT IMPLEMENTED; evidence tenant isolation BLOCKED (`TENANT-004`) |
| 6 | Dev flag enabled in a deployed environment | config | Phase 0: PARTIAL → Phase 1: no longer applicable — `ALLOW_DEV_ACTOR_HEADERS` and the header path were removed; the headers are ignored even beside a valid token (AUTH-011, ATTACK-P1-010). Superseded by rows 9–10 |
| 7 | Queue consumer does not fire under `wrangler dev`, so async processing is unverified end-to-end | Queue `claim-events` | NOT TESTED live (unit tested in `test/queue.test.ts`); re-observed in Phase 1: no consumer log lines |
| 8 | Rate limit is per-IP and approximate | `src/index.ts` | PARTIAL: Phase 1 added a per-actor limit after authentication (same binding); still approximate by design |
| 9 | Leaked or weak `JWT_SECRET` lets anyone mint any role and tenant (Phase 1) | Worker secret binding, `.dev.vars` | PARTIAL: ≥ 32 bytes enforced, secret binding only, gitignored locally, missing secret fails closed; no rotation procedure, no asymmetric keys / IdP (PLANNED) |
| 10 | Stolen valid token replayed until expiry (Phase 1) | all `/api/v1/*` | PARTIAL: TTL capped (24 h / 8 h) and per-actor rate limit; no revocation or `jti` denylist (PLANNED) |
| 11 | Same manager decides and pays the same claim | `/decide`, `/pay` | DECISION REQUIRED (no check in code) |
| 12 | ADMIN token scope (platform vs tenant) | token `tenant_id` (optional, not used for authorization) | DECISION REQUIRED (ADMIN currently has no powers, so exposure is nil today) |
