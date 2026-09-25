# Threat Model

Scope: `backend/` Cloudflare Worker (Hono), D1 database `DB`, Queue `CLAIM_EVENTS`. There is no frontend in this repo.

## Assets

| Asset | Where | Sensitivity |
|---|---|---|
| Claims (owner, policy, stage, status, cause of loss, incident date) | D1 `claims` | High: health, vehicle and life incidents (POPIA special personal information) |
| Policies | D1 `policies` | Medium–High |
| Audit trail | D1 `audit_events` | High (integrity) |
| Evidence metadata (future) | D1 `evidence` (table exists, unused) | High |
| Claim decision and payout (future) | not implemented | Critical (money) |
| Debit-order mandates (future) | `/profile/mandates/*` stubs | High (money) |
| Configuration: CORS origins, rate limits, dev auth flag | `wrangler.toml`, `.dev.vars` | High |

## Actors

| Actor | Capability | Goal |
|---|---|---|
| Customer (`CUSTOMER`) | Own claims and policies | Legitimate use. May also inflate or fake a claim |
| Assessor / Manager | Read all claims (no tenant scope yet). Future: verify, screen, decide, pay | Legitimate use; insider fraud risk |
| Admin | Configuration and users (future). No claim powers by design | Misconfiguration or abuse |
| External attacker | Unauthenticated HTTP | Data theft, abuse, denial of service |
| Compromised insider | A valid insurer role | Approve or pay fraudulent claims, read other insurers' claims |
| Malicious document | Uploaded evidence (future) | Exploit parsers, inject prompts into AI/OCR |

## Trust boundaries

1. **Client → Worker** (`/api/v1/*`): all input is untrusted. Controls: actor resolution (dev stub; real auth is not implemented), zod validation, body limit, rate limit, CORS.
2. **Worker → D1**: parameterised queries only. The audit table has triggers that block UPDATE/DELETE.
3. **Worker → Queue producer**: only server-built payloads are sent (`claims.ts` submit and evidence-ocr).
4. **Queue → consumer** (`ocr.ts` `processQueueBatch`): messages are re-validated with zod; malformed ones are acked and dropped.
5. **Future OCR/AI**: output is an untrusted signal and never a decision (AI_SECURITY.md).
6. **Future object storage (R2)**: private bucket, server-generated keys (EVIDENCE_SECURITY.md).

## STRIDE per component

| Component | S | T | R | I | D | E |
|---|---|---|---|---|---|---|
| Actor resolution (`src/security/actor.ts`) | **High**: dev headers are spoofable when the flag is on | — | Actor ID is recorded in audit | — | — | Role header grants any role (dev only) |
| Claim routes (`src/endpoints/claims.ts`) | Depends on auth | Mass assignment blocked (strict schemas) | Audit on create, screening, evidence, transitions, denials | IDOR blocked (404, no existence oracle) | Body limit and per-IP rate limit | State machine blocks illegal jumps; customer can't decide or pay |
| Policy routes (`src/endpoints/policy.ts`) | Depends on auth | `join-request` strict | Audited | `my-covers` scoped to the actor | Rate limit | CUSTOMER only |
| OCR route + consumer (`src/endpoints/ocr.ts`) | — | Queue payload validated | Console logs only | — | Malformed messages acked (no infinite retry) | `/ocr/process` limited to ASSESSOR/MANAGER |
| Profile/mandates (`src/endpoints/identity.ts`) | Depends on auth | PATCH profile is a no-op stub | Mandate cancel audited | Stubs return empty data | Rate limit | Mandate cancel is CUSTOMER only; `tenantId` is unscoped |
| D1 audit table | — | UPDATE/DELETE blocked by triggers | This is the repudiation control | No narratives or PII stored | — | A DB admin can still drop triggers (out of app scope) |
| Config (`wrangler.toml`, `.dev.vars`) | — | Deploy-time only, no runtime config API | Git history only | No secrets in repo | — | Enabling the dev flag in prod is total auth bypass |

## Top risks tied to actual endpoints

| # | Risk | Endpoint(s) | Status |
|---|---|---|---|
| 1 | No real authentication | all `/api/v1/*` | NOT IMPLEMENTED: fails closed, and the dev stub is spoofable |
| 2 | Insurer staff can read every claim (no org scope) | `GET /claims/:claimId/timeline`, `/decision` | NOT IMPLEMENTED |
| 3 | No insurer workflow endpoints, so verify/screen/decide/pay can't be driven or tested over HTTP | (none exist) | PLANNED |
| 4 | Payout and mandates are stubs, so the money path has no controls | `/profile/mandates/*` | NOT IMPLEMENTED |
| 5 | Evidence upload doesn't exist; the endpoint only queues an event | `POST /claims/:claimId/evidence-ocr` | NOT IMPLEMENTED |
| 6 | Dev flag enabled in a deployed environment | config | PARTIAL: documented, no automated guard |
| 7 | Queue consumer does not fire under `wrangler dev`, so async processing is unverified end-to-end | Queue `claim-events` | NOT TESTED live (unit tested in `test/queue.test.ts`) |
| 8 | Rate limit is per-IP and approximate | `src/index.ts` | PARTIAL |
