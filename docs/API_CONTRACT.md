# EasyClaim API contract

The single contract between `frontend/` (Flutter) and `backend/` (Hono Worker). Source of truth is the code in
`backend/src/endpoints/*` (incl. `auth.ts`, `admin.ts`), `backend/src/screening/routes.ts`, `backend/src/integrity/routes.ts`; this document is
checked by `backend/test/endToEnd.test.ts` and `backend/test/attackSuite.test.ts`. Frontend consumers are the
repositories in `frontend/lib/data/repositories/`.

## Conventions

| Topic | Rule |
|---|---|
| Base URL | `http://127.0.0.1:8787/api/v1` locally (Android emulator: `http://10.0.2.2:8787/api/v1`). Flutter: `--dart-define=API_BASE_URL=...` |
| Roles | `CUSTOMER` (platform-level, self-registers), `INSURER_ADMIN` (one role per insurer/tenant: verify … pay, plus own-tenant accounts), `SUPERADMIN` (platform operator: insurers, accounts, stats; read-only on claims) |
| Auth | `Authorization: Bearer <JWT>` on every route except `POST /auth/login` and `POST /auth/register`. Identity, role and tenant come only from the verified token, which is issued from the `users` table |
| Never trusted | `X-User-Id`, `X-Role`, `X-Tenant-Id` headers (ignored); `userId`, `role`, `tenantId`, `stage`, `status`, scores, amounts outside the listed fields (400) |
| Bodies | JSON, max 64 KB; strict schemas: an unknown field is `400 validation_failed` with `issues[]`. Evidence: `multipart/form-data`, field `file`, max 10 MiB |
| IDs | `^[A-Za-z0-9_-]{1,64}$`. Claim ids `claim_<uuid>` |
| Money | integer cents (`*Cents`, `*_cents`). R4 200 = `420000` |
| Dates | ISO-8601 strings; `incidentDate` is `YYYY-MM-DD` and not in the future |
| Stages | `Draft, Submitted, Verified, Screening, Review, Decision, Paid, Info Needed, Appeal, Withdrawn, Expired` (title case, exact) |
| Status | `Pending` until a decision; then `Approved` or `Rejected` (seed also has `Processing`) |
| Errors | `{"error":"<snake_case_code>", ...}`; every response carries `X-Request-Id` |
| Not found vs forbidden | A claim you may not see (other customer, other tenant, someone's Draft) is `404 not_found`, identical to a missing one. A route your role may not use is `403 forbidden` |
| Pagination | `GET /claims?limit=1..50` (default 20), newest first. No cursor |
| Naming | list endpoints return DB rows (snake_case); detail/action endpoints return camelCase. The Flutter models map both explicitly |

Error codes the app must handle:

| HTTP | Codes | App message |
|---|---|---|
| 400 | `validation_failed`, `client_supplied_fields`, `invalid_idempotency_key`, `file_required`, `invalid_upload` | "Some details are missing or invalid." |
| 401 | `unauthenticated`, `invalid_credentials` | "Your session has expired. Please sign in again." (login: "Wrong username or password.") |
| 403 | `forbidden` | "You don't have permission to do that." |
| 404 | `not_found` | "Claim not found." |
| 409 | `illegal_transition`, `stale_state`, `claim_not_editable`, `payout_details_locked`, `not_appealable`, `already_paid`, `not_approved`, `decision_integrity_failed`, `destination_mismatch` | "This claim has changed. Refresh and try again." (`decision_integrity_failed`: "Payout blocked: the decision failed its integrity check.") |
| 413 / 415 | `payload_too_large`, `file_too_large` / `unsupported_file_type` | "File too large" / "Only PDF, JPEG or PNG" |
| 422 | `policy_not_eligible`, `screening_incomplete`, `payout_details_missing`, `amount_exceeds_claimed`, `amount_not_allowed_for_rejection`, `unknown_plan` | specific text per code |
| 429 | `rate_limited` | "Too many requests. Wait a moment." |
| 500 / 503 | `internal_error` (+`requestId`), `storage_unavailable`, `integrity_unavailable`, `auth_unavailable` | "Something went wrong. Please try again." |

## Authentication and accounts

| | |
|---|---|
| **POST /auth/login** | Sign in. Public (per-IP rate limit applies) |
| Request | `{ "username": "mike", "password": "…" }` strict; username 3–64 `[A-Za-z0-9_-]` (case-insensitive), password ≥ 6 |
| Response 200 | `{ token, tokenType:"Bearer", expiresIn:3600, actor:{ id, username, role, tenantId, displayName, status, createdAt } }` |
| Errors | 401 `invalid_credentials` (unknown user, wrong password or disabled account: same body, same timing), 400, 503 `auth_unavailable` |
| Audit | `auth.login` success / denied (never the password) |
| Frontend | `AuthRepository.signIn` |

| | |
|---|---|
| **POST /auth/register** | Self-service customer account. Public |
| Request | `{ username, password, displayName }` strict; a `role`/`tenantId` field → 400 |
| Response 201 | same session body as login, `actor.role` always `CUSTOMER` |
| Errors | 409 `username_taken`, 400 |
| Audit | `auth.register` |
| Frontend | `AuthRepository.register` |

| | |
|---|---|
| **GET /auth/me** | The verified actor + profile |
| Response | `{ actor:{ id, role, tenantId, username, displayName, status } }` (profile fields null for offline-minted tokens) |

Passwords are PBKDF2-SHA256 hashes (`backend/src/security/password.ts`); no route ever returns a hash. Insurer admins
and superadmins are created by a SUPERADMIN (below), never by registration. Demo accounts (local only, all with the
password in `backend/.dev.vars`, agreed value `1234567`): `mike`, `lerato`, `sipho` (customers), `admin_discovery`,
`admin_sanlam` (insurer admins), `superadmin`.

KNOWN LIMITATIONS: no token revocation (a disabled account's token lives ≤ 1 h), no password reset, no MFA, one shared
HS256 secret (BACKEND-SEC-019).

## Platform administration (SUPERADMIN only; others 403)

| Method + path | Request | Response | Errors | Audit | Frontend |
|---|---|---|---|---|---|
| GET `/admin/stats` | – | `{tenants, usersByRole:{CUSTOMER,INSURER_ADMIN,SUPERADMIN}, claims:{total, byStage}, perTenant:[{tenantId,name,claims:{total,byStage}}]}` | 403 | – | superadmin dashboard |
| GET `/admin/tenants` | – | `{tenants:[{id,name,admin_count,policy_count,claim_count}]}` | 403 | – | Insurers screen |
| POST `/admin/tenants` | `{id ^ins_[a-z0-9_]{2,40}$, name}` | 201 `{tenant:{id,name}}` | 400, 409 `tenant_exists` | `admin.tenant_created` | Add insurer |
| GET `/admin/users?tenantId=` | – | `{users:[User]}` (no tenant filter = all non-customer accounts) | 403 | – | Accounts screen |
| POST `/admin/users` | `{username, password, displayName, role: INSURER_ADMIN\|SUPERADMIN, tenantId?}` (required for INSURER_ADMIN, forbidden for SUPERADMIN) | 201 `{user}` | 409 `username_taken`, 422 `tenant_required`/`unknown_tenant`/`tenant_not_allowed` | `admin.user_created` | Add account |
| PATCH `/admin/users/:userId` | `{status: active\|disabled}` | `{user}` | 404, 409 `cannot_change_own_status` | `admin.user_status_changed` | enable/disable |
| GET `/claims?limit=&tenantId=` | – | platform-wide non-Draft list (no `user_id`) | – | – | Claims screen |
| GET `/claims/:id`, `/timeline`, `/decision`, `/payout`, `/evidence`, `/decision/verify` | – | read-only, non-Draft | 404 | – | read-only detail |

SUPERADMIN gets 403 on every insurer action (`verify`, `screen`, `review`, `request-info`, `decide`, `pay`) and on
`/risk-signals`, and 404 on Drafts.

## Tenant administration (INSURER_ADMIN, own tenant only)

| Method + path | Request | Response | Errors | Audit | Frontend |
|---|---|---|---|---|---|
| GET `/tenant` | – | `{tenant:{id,name}}` | 403 | – | Team screen |
| GET `/tenant/stats` | – | `{tenantId, claims:{total, byStage}}` | 403 | – | Team screen |
| GET `/tenant/users` | – | `{users:[User]}` own tenant | 403 | – | Team screen |
| POST `/tenant/users` | `{username, password, displayName}` (a `tenantId` → 400; tenant comes from the token) | 201 `{user}` INSURER_ADMIN | 409 | `tenant.user_created` | Add admin |
| PATCH `/tenant/users/:userId` | `{status}` | `{user}` | 404 (other tenant), 409 (self) | `tenant.user_status_changed` | enable/disable |

## Customer

| Method + path | Role / tenant rule | Request | Response 200/201 | Errors | State | Audit | Frontend |
|---|---|---|---|---|---|---|---|
| GET `/covers/my-covers` | CUSTOMER, own policies | – | `{policies:[{id,user_id,plan_name,status,tenant_id,insurer_name}]}` | 403 | – | – | `CoversRepository.myPolicies` |
| GET `/covers/market-catalog` | any | – | `{catalog:[{id,provider,name,premium}]}` (static) | – | – | – | not used (UI keeps its static insurer list) |
| GET `/claims?limit=` | CUSTOMER: own. INSURER_ADMIN: own tenant, no Drafts, no `user_id`. SUPERADMIN: all tenants, no Drafts, optional `tenantId` | – | `{claims:[{id,policy_id,tenant_id,stage,status,category,claimed_amount_cents,created_at,updated_at}]}` | 403 | – | denied only | `ClaimsRepository.list`, `InsurerRepository.queue` |
| POST `/claims/initiate` | CUSTOMER, owns an Active policy with a tenant | `{policyId, category?: Medical\|Vehicle\|Life\|Property\|Other}` | 201 `{status:"draft_created", claimId}` | 400, 422 `policy_not_eligible` | creates Draft | `claim.created` | `ClaimsRepository.create` |
| POST `/claims/verify-eligibility` | CUSTOMER | `{policyId}` | `{verified, context:{isIdentityValid:null,isPolicyActive,waitingPeriodCleared:null}}` | 400 | – | – | wizard step 2 |
| PATCH `/claims/:id/screening` | owner | `{causeOfLoss (1..2000), incidentDate}` | `{status:"screening_updated", message}` | 404, 409 `claim_not_editable` | Draft or Info Needed (Info Needed → Screening) | `claim.screening_updated` | `ClaimsRepository.describe` |
| PUT `/claims/:id/payout-details` | owner | `{claimedAmountCents 1..1e8, bankName, accountHolder, accountNumber ^[0-9]{6,20}$}` | `{status:"payout_details_saved", claimedAmountCents, destination:{bankName, accountLast4}}` | 404, 409 `payout_details_locked` | Draft / Info Needed | `claim.payout_details_set` | `ClaimsRepository.setPayoutDetails` |
| POST `/claims/:id/evidence` | owner | multipart `file` (PDF/JPEG/PNG ≤ 10 MiB; declared type must match bytes) | 201 `{status:"uploaded", evidenceId, sha256}` | 400, 404, 409, 413, 415, 503 | Draft / Info Needed | `evidence.uploaded` / `evidence.rejected` | `ClaimsRepository.uploadEvidence` |
| GET `/claims/:id/evidence` | owner or tenant staff | – | `{evidence:[{id,display_name,mime_type,size_bytes,sha256,created_at}]}` | 404 | – | – | claim detail |
| GET `/claims/:id/evidence/:eid/verify` | owner or tenant staff | – | `{status:"VALID"\|"TAMPERED", evidenceId, expectedHash, actualHash}` | 404 | – | `evidence.integrity_verified` | insurer detail |
| POST `/claims/:id/submit` | owner | – | `{status:"submitted", message, claimId}` | 404, 409, 422 `screening_incomplete` | Draft → Submitted | `claim.stage_changed` | `ClaimsRepository.submit` |
| GET `/claims/:id` | owner, tenant insurer admin or SUPERADMIN (not Draft for the latter two) | – | `{claim:{id,policyId,planName,tenantId,insurerName,stage,status,category,causeOfLoss,incidentDate,claimedAmountCents,payoutDestination:null\|{bankName,accountLast4},createdAt,updatedAt}}` | 404 | – | denied only | `ClaimsRepository.detail` |
| GET `/claims/:id/timeline` | owner or tenant staff | – | `{claimId, currentStage, timeline:[{stage, date\|null, completed}]}` (6 main stages) | 404 | – | – | claim tracking |
| GET `/claims/:id/decision` | owner or tenant staff | – | `{decision:"Approved"\|"Rejected"\|"pending", record:null\|{id,decidedAt,decidedByRole,reason,approvedAmountCents,rulesVersion,evidenceDigest}}` | 404 | – | – | decision card |
| GET `/claims/:id/decision/verify` | owner or tenant staff | – | `{claimId, decisionId\|null, integrity:{status, alg, keyId, bundleDigest, recomputedDigest}}`; status `VALID`/`TAMPERED`/`UNSIGNED`/`UNKNOWN_KEY`/`UNAVAILABLE`/`NO_DECISION` | 404 | – | `decision.integrity_verified` | integrity card |
| GET `/claims/:id/payout` | owner or tenant staff | – | `{claimId, stage, claimedAmountCents, destination, decision:null\|{id,outcome,approvedAmountCents,decidedAt,decidedByRole}, payout:null\|{id,amountCents,destinationLast4,status,initiatedAt}}` | 404 | – | – | payout card |
| POST `/claims/:id/appeal` | owner | `{reason}` | `{status:"appealed"}` | 404, 409 `not_appealable` | Decision + Rejected → Appeal | `claim.stage_changed` | appeal button |
| GET `/integrity/public-key` | any authenticated | – | `{alg:"ML-DSA-65", standard:"NIST FIPS 204", keyId, bundleVersion, context, publicKey}` | 503 | – | – | not used by the app (outside verifiers) |

Customers and superadmins never see risk signals (`/risk-signals` is 403 for them); customers never see another party's data.

## Insurer (INSURER_ADMIN of the claim's tenant; claim not in Draft; otherwise 404)

| Method + path | Role | Request | Response 200 | Errors | Edge | Audit | Frontend |
|---|---|---|---|---|---|---|---|
| POST `/claims/:id/verify` | INSURER_ADMIN | none | `{status:"transitioned", claimId, from, to:"Verified"}` | 403, 404, 409 | Submitted → Verified | `claim.stage_changed` | `InsurerRepository.advance` |
| POST `/claims/:id/screen` | INSURER_ADMIN | none (a body is ignored) | `{..., to:"Screening", riskSignals: RiskSignals\|null}` | same | Verified → Screening | + `screening.signal_attached` | same |
| POST `/claims/:id/review` | INSURER_ADMIN | none | `{..., to:"Review"}` | same | Screening/Appeal → Review | `claim.stage_changed` | same |
| POST `/claims/:id/request-info` | INSURER_ADMIN | none | `{..., to:"Info Needed"}` | same | Screening/Review → Info Needed | same | same |
| GET `/claims/:id/risk-signals` | INSURER_ADMIN | – | `{claimId, stage, riskSignals: RiskSignals\|null}` | 403 customer, 404 | – | `screening.signal_read` | screening card |
| POST `/claims/:id/decide` | INSURER_ADMIN | `{outcome:"Approved"\|"Rejected", reason, approvedAmountCents?}` (no amount on Rejected; omitted = full claimed amount) | `{..., to:"Decision", outcome, decisionId, approvedAmountCents, evidenceCount, evidenceDigest, integrity:{alg,keyId,bundleDigest}}` | 400, 403, 404, 409, 422, 503 `integrity_unavailable` | Review → Decision | `claim.decision_recorded` | `InsurerRepository.decide` |
| POST `/claims/:id/pay` | INSURER_ADMIN | **empty**; optional `Idempotency-Key` | `{status:"paid", simulated:true, claimId, payoutId, decisionId, amountCents, destination}`; replay: `{status:"already_paid", ...}` | 400, 403, 404, 409 | Decision(Approved) → Paid | `payout.completed_simulated` / `payout.blocked` | `InsurerRepository.pay` |

`RiskSignals`:
```
{ classicalAnomaly: 0..1, quantumAnomaly: 0..1, interpretation: NORMAL|UNUSUAL|HIGH_ANOMALY,
  anomalyBand: NORMAL|ELEVATED|HIGH, screeningRecommendation: STANDARD_REVIEW|REVIEW_REQUIRED,
  explanation, versions:{model,features,kernel,screening}, signalDigest, modelVersion,
  execution: simulator|hardware, computedAt, advisory: true }
```
The signal is advisory. It never changes stage, status, eligibility or payout. Only the offline pipeline
(`quantum/`) writes it; no route accepts it.

## Demo stubs (fixed data, not authoritative)

`/client/*`, `GET|PATCH /profile`, `/profile/consent`, `/profile/mandates/*`, `/activities/*`, `/ocr/process`,
`POST /covers/join-request`. The app does not rely on them for business state.

## Not in the API (do not call)

`/dashboard`, `/profile/register`, `/profile/login` (removed), `/auth/demo-login` (removed), `/decisions`, `/covers`, `/covers/market`, any
withdraw route, `GET /claims/:id/risk-signals` for customers. The unmounted `backend/legacy/` code is not an API.

## Flutter stage mapping (`frontend/lib/data/models/claim_stage.dart`)

| Backend `stage` (+ `status`) | App `ClaimStage` | App side state |
|---|---|---|
| Draft | (draft, not on the 6-step bar) | – |
| Submitted, Verified, Screening, Review, Decision, Paid | same | – |
| Info Needed | screening | infoNeeded |
| Decision + Rejected | decision | rejected |
| Appeal | review | appeal |
| Withdrawn, Expired | terminal label | – |
