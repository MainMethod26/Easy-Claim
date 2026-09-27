# EasyClaim API contract

The single contract between `frontend/` (Flutter) and `backend/` (Hono Worker). Source of truth is the code in
`backend/src/endpoints/*` (incl. `auth.ts`, `admin.ts`), `backend/src/screening/routes.ts`, `backend/src/integrity/routes.ts`; this document is
checked by `backend/test/endToEnd.test.ts` and `backend/test/attackSuite.test.ts`. Frontend consumers are the
repositories in `frontend/lib/data/repositories/`.

## Conventions

| Topic | Rule |
|---|---|
| Base URL | `http://127.0.0.1:8787/api/v1` locally (Android emulator: `http://10.0.2.2:8787/api/v1`). Flutter: `--dart-define=API_BASE_URL=...` |
| Roles | `CUSTOMER`, `ASSESSOR`, `MANAGER`, `INSURER_ADMIN`, `SUPERADMIN`: see the table below |
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

| Role | Tenant | Can | Cannot |
|---|---|---|---|
| `CUSTOMER` | – | register, file and track own claims, appeal | see anyone else's data, screening signals |
| `ASSESSOR` | required | verify, screen, review, request information on its insurer's claims; see screening signals | decide, pay, re-open appeals |
| `MANAGER` | required | everything an assessor does + decide, pay (simulated), re-open appeals | act on another insurer's claims |
| `INSURER_ADMIN` | required | manage its insurer's staff (create assessors, managers, admins; enable/disable), tenant stats, read its insurer's claims | move a claim, see screening signals |
| `SUPERADMIN` | – | platform operator: review insurer applications, create insurers and insurer admins, aggregate dashboards (overview, security, integrity, audit) | see or move any claim, evidence or screening signal; manage assessors/managers; cannot be created through the API |

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
| **POST /auth/insurer-applications** | Public: an insurance company applies to join. Nothing is created until a SUPERADMIN approves |
| Request | `{ companyName, fspNumber ^[0-9]{1,8}$, contactEmail, adminUsername, adminDisplayName, password }` strict |
| Response 201 | `{ application:{ id, status:'pending', companyName } }` |
| Errors | 400, 409 `username_taken` / `application_pending` (one pending per username and per FSP number), 429 `applications_paused` |
| Audit | `onboarding.application_submitted` |
| Frontend | `AuthRepository.applyAsInsurer` |

| | |
|---|---|
| **GET /auth/me** | The verified actor + profile |
| Response | `{ actor:{ id, role, tenantId, username, displayName, status } }` (profile fields null for offline-minted tokens) |

Passwords are PBKDF2-SHA256 hashes (`backend/src/security/password.ts`); no route ever returns a hash. Insurer admins
are created by a SUPERADMIN; assessors, managers and further insurer admins by their tenant's INSURER_ADMIN;
superadmins only by the bootstrap script. Demo accounts (local only, password from `backend/.dev.vars`, agreed value
`1234567`): `mike`, `lerato`, `sipho` (customers), `assessor_discovery`, `manager_discovery`, `assessor_sanlam`,
`manager_sanlam`, `admin_discovery`, `admin_sanlam` (insurer admins), `superadmin`.

KNOWN LIMITATIONS: no token revocation (a disabled account's token lives ≤ 1 h), no password reset, no MFA, one shared
HS256 secret (BACKEND-SEC-019).

## Platform administration (SUPERADMIN only; others 403)

| Method + path | Request | Response | Errors | Audit | Frontend |
|---|---|---|---|---|---|
| GET `/admin/stats` | – | `{tenants, usersByRole:{CUSTOMER,INSURER_ADMIN,SUPERADMIN}, claims:{total, byStage}, perTenant:[{tenantId,name,claims:{total,byStage}}]}` | 403 | – | superadmin dashboard |
| GET `/admin/tenants` | – | `{tenants:[{id,name,admin_count,policy_count,claim_count}]}` | 403 | – | Insurers screen |
| POST `/admin/tenants` | `{id ^ins_[a-z0-9_]{2,40}$, name}` | 201 `{tenant:{id,name}}` | 400, 409 `tenant_exists` | `admin.tenant_created` | Add insurer |
| GET `/admin/users?tenantId=` | – | `{users:[User]}` (no tenant filter = all non-customer accounts) | 403 | – | Accounts screen |
| POST `/admin/users` | `{username, password, displayName, tenantId, role?: "INSURER_ADMIN"}` (only insurer admins; any other role → 400) | 201 `{user}` | 400, 409 `username_taken`, 422 `unknown_tenant` | `admin.user_created` | Add account |
| PATCH `/admin/users/:userId` | `{status: active\|disabled}` | `{user}` | 404, 409 `cannot_change_own_status` / `superadmin_managed_offline` | `admin.user_status_changed` | enable/disable |
| GET `/admin/overview?days=1..365` (default 30) | – | `PlatformOverview {generatedAt, windowDays, tenants, usersByRole, claims:{total,open,byStage}, decisions:{windowDays,approved,rejected,approvalRate,medianHoursToDecision}, payouts:{windowDays,count,totalCents}, perTenant:[PlatformTenantSummary {id,name,claims,openClaims,staff,activeAdmins,decisionsInWindow,payoutsInWindow}]}` | 400, 403 | – | Platform overview |
| GET `/admin/security?days=` | – | `PlatformSecurity {logins:{success,denied}, deniedByAction, failuresByAction, deniedByTenant, disabledAccounts, recentDenied:[AdminAuditEvent], notMeasured:[string]}` | 400, 403 | – | Security centre |
| GET `/admin/integrity?days=` | – | `PlatformIntegrity {decisions:{total,signed,unsigned,byKeyId}, verificationsInWindow:{STATUS:n}, screening:{NORMAL,ELEVATED,HIGH,unscreened,byExecution,byModelVersion}}` | 400, 403 | – | Integrity & crypto |
| GET `/admin/audit?limit=1..100&before=&outcome=&action=&tenantId=` | – | `{events:[AdminAuditEvent {id,occurredAt,actorId,actorRole,action,resourceType,resourceId,outcome}], nextBefore}` (never `details`) | 400, 403 | `admin.audit_viewed` | Global audit |
| GET `/admin/applications?status=pending\|approved\|rejected` | – | `{applications:[{id,companyName,fspNumber,contactEmail,adminUsername,adminDisplayName,status,tenantId,decisionReason,decidedAt,createdAt}]}` (never the password hash) | 400, 403 | – | Applications |
| POST `/admin/applications/:applicationId/approve` | `{tenantId ^ins_[a-z0-9_]{2,40}$}` | `{application}` approved; creates the tenant (company name) and its INSURER_ADMIN in one batch | 400, 404, 409 `already_decided`/`tenant_exists`/`username_taken` | `onboarding.application_approved`, `admin.tenant_created`, `admin.user_created` | Approve |
| POST `/admin/applications/:applicationId/reject` | `{reason 5..500}` | `{application}` rejected | 400, 404, 409 `already_decided` | `onboarding.application_rejected` | Reject |
| GET `/claims?limit=&tenantId=` | – | platform-wide non-Draft list (no `user_id`) | – | – | Claims screen |
| GET `/claims`, `/claims/:id`, `/timeline`, `/decision`, `/payout`, `/evidence`, `/decision/verify` | – | never (27 Sep 2026): `/claims` 403, per-claim routes 404 | 403, 404 | `authz.*_denied` | – |

SUPERADMIN gets 403 on every insurer action (`verify`, `screen`, `review`, `request-info`, `decide`, `pay`) and on
`/risk-signals`, and no read access to any claim (it sees aggregate counts on `/admin/overview` and `/admin/integrity` only).

## Tenant administration (INSURER_ADMIN, own tenant only)

The insurer admin also reads its own tenant's non-Draft claims (`GET /claims`, `/claims/:id`, timeline, decision,
payout, evidence, decision/verify) and gets 403 on every claim action and on `/risk-signals`.


| Method + path | Request | Response | Errors | Audit | Frontend |
|---|---|---|---|---|---|
| GET `/tenant` | – | `{tenant:{id,name}}` | 403 | – | Team screen |
| GET `/tenant/stats` | – | `{tenantId, claims:{total, byStage}}` | 403 | – | Team screen |
| GET `/tenant/users` | – | `{users:[User]}` own tenant | 403 | – | Team screen |
| POST `/tenant/users` | `{username, password, displayName, role: ASSESSOR\|MANAGER\|INSURER_ADMIN}` (a `tenantId` → 400; tenant comes from the token) | 201 `{user}` | 400, 409 | `tenant.user_created` | Add staff |
| PATCH `/tenant/users/:userId` | `{status}` | `{user}` | 404 (other tenant), 409 (self) | `tenant.user_status_changed` | enable/disable |
| GET `/tenant/overview?days=1..365` (default 30) | – (`tenantId` → 400) | `TenantOverview {tenant, generatedAt, claims, decisions, payouts, screening:{NORMAL,ELEVATED,HIGH,unscreened}, integrity:{signed,unsigned,verificationsInWindow}, staff:{byRole,active,disabled}}` | 400, 403 | – | Insurer overview |
| GET `/tenant/audit?limit=&before=&outcome=&action=` | – (`tenantId` → 400) | `{events:[AdminAuditEvent], nextBefore}`, own tenant's scope; actors outside the tenant shown by role only (`actorId: null`) | 400, 403 | `tenant.audit_viewed` | Insurer audit log |
| GET `/tenant/policy-requests?status=pending\|more_info\|approved\|rejected` | – | `{requests:[{id,tenantId,insurerName,policyNumber,status,policyId,decisionReason,decidedAt,createdAt,customer:{displayName,username}}]}` own tenant | 400, 403 | – | Policy requests |
| POST `/tenant/policy-requests/:requestId/approve` | `{planName 2..100}` | `{request}` approved; creates an Active policy for the customer. Requires the client's details and every required document uploaded and checked | 400, 404 (other tenant), 409 `documents_incomplete`/`waiting_for_customer`/`already_decided`/`policy_already_linked` | `policy.link_approved` | Approve |
| POST `/tenant/policy-requests/:requestId/reject` | `{reason 5..500}` | `{request}` rejected | 400, 404, 409 | `policy.link_rejected` | Decline |
| GET `/tenant/policy-requests/:requestId` | – | `{request:{id,policyNumber,status,infoMessage,decisionReason,createdAt,client:{easyclaimId,displayName,username,profile(ID masked)},documents:[{key,label,required,uploaded,fileName,sizeBytes,sha256,uploadedAt,verified}],readyToApprove}}` | 403, 404 (other tenant) | – | Request detail |
| POST `/tenant/policy-requests/:requestId/reveal-id` | – | `{idNumber}` | 403, 404, 503 | `onboarding.id_number_revealed` | Reveal (recorded) |
| GET `/tenant/policy-requests/:requestId/documents/:docKey` | – | file bytes, `Cache-Control: no-store`, `X-Document-SHA256` | 403, 404 | `onboarding.document_accessed` | Open document |
| POST `/tenant/policy-requests/:requestId/documents/:docKey/verify` | `{verified: boolean}` | `{documents}` | 403, 404, 409 `not_pending` | `onboarding.document_verified` / `_unverified` | Checked |
| POST `/tenant/policy-requests/:requestId/request-info` | `{message 5..500}` | `{status:'more_info'}` | 400, 404, 409 | `policy.link_more_info` | Ask for more |
| GET `/tenant/requirements` | – | `{requirements:[{key,label,required}]}` own tenant | 403 | – | Required docs |
| PUT `/tenant/requirements` | `{items:[{key ^[a-z][a-z0-9_]{1,39}$, label, required}]}` max 10, unique keys | `{requirements}` | 400, 403 | `tenant.requirements_changed` | Required docs |
| GET `/tenant/customers?easyclaimId=EC-XXXX-XXXX` | – | `{customer:{easyclaimId,displayName,related,client(null unless related),requests,policies}}` exact match | 400, 403, 404 | `tenant.customer_lookup` | EasyClaim ID search |

## Customer

| Method + path | Role / tenant rule | Request | Response 200/201 | Errors | State | Audit | Frontend |
|---|---|---|---|---|---|---|---|
| GET `/covers/my-covers` | CUSTOMER, own policies | – | `{policies:[{id,user_id,plan_name,status,tenant_id,policy_number,insurer_name}]}` | 403 | – | – | `CoversRepository.myPolicies` |
| GET `/covers/insurers` | CUSTOMER | – | `{insurers:[{id,name}]}` | 403 | – | – | `CoversRepository.insurers` |
| GET `/covers/link-requests` | CUSTOMER, own requests | – | `{requests:[{id,tenantId,insurerName,policyNumber,status,policyId,decisionReason,decidedAt,createdAt}]}` | 403 | – | – | `CoversRepository.linkRequests` |
| POST `/covers/link-requests` | CUSTOMER | `{tenantId, policyNumber ^[A-Za-z0-9-]{4,32}$}` | 201 `{request}` pending | 400, 403, 404 `unknown_insurer`, 409 `request_pending`/`policy_already_linked` | – | `cover.link_requested` | `CoversRepository.requestLink` |
| GET `/covers/profile` | CUSTOMER | – | `{easyclaimId, profile:null\|{legalName,email,phone,dateOfBirth,idNumberMasked,updatedAt}}` | 403 | – | – | `CoversRepository.profile` |
| PUT `/covers/profile` | CUSTOMER | `{legalName, email, phone, dateOfBirth YYYY-MM-DD, idNumber 13 digits}` (SA ID: Luhn + must match DOB) | `{easyclaimId, profile}` (ID only masked; stored AES-GCM encrypted) | 400 `invalid_id_number`/`id_number_date_mismatch`, 403, 503 `pii_unavailable` | – | `customer.profile_saved` | `CoversRepository.saveProfile` |
| GET `/covers/insurers/:tenantId/requirements` | CUSTOMER | – | `{requirements:[{key,label,required}]}` | 400, 403 | – | – | Link a policy |
| POST `/covers/link-requests/:requestId/documents/:docKey` | CUSTOMER, own open request | multipart `file` (PDF/JPEG/PNG, magic bytes, ≤10 MB) | 201 `{documents:[checklist]}`; re-upload un-checks it | 400, 404, 409 `request_closed`, 413, 415, 503 | – | `onboarding.document_uploaded` / `_rejected` | `CoversRepository.uploadRequestDocument` |
| POST `/covers/link-requests/:requestId/resubmit` | CUSTOMER | – | `{status:'pending'}` (from `more_info`) | 404, 409 `not_waiting_for_you` | – | `cover.link_resubmitted` | `CoversRepository.resubmit` |
| GET `/covers/market-catalog` | any | – | `{catalog:[{id,provider,name,premium}]}` (static) | – | – | – | not used (UI keeps its static insurer list) |
| GET `/claims?limit=` | CUSTOMER: own. ASSESSOR / MANAGER / INSURER_ADMIN: own tenant, no Drafts, no `user_id`. SUPERADMIN: 403 | – | `{claims:[{id,policy_id,tenant_id,stage,status,category,claimed_amount_cents,created_at,updated_at}]}` | 403 | – | denied only | `ClaimsRepository.list`, `InsurerRepository.queue` |
| POST `/claims/initiate` | CUSTOMER, owns an Active policy with a tenant | `{policyId, category?: Medical\|Vehicle\|Life\|Property\|Other}` | 201 `{status:"draft_created", claimId}` | 400, 422 `policy_not_eligible` | creates Draft | `claim.created` | `ClaimsRepository.create` |
| POST `/claims/verify-eligibility` | CUSTOMER | `{policyId}` | `{verified, context:{isIdentityValid:null,isPolicyActive,waitingPeriodCleared:null}}` | 400 | – | – | wizard step 2 |
| PATCH `/claims/:id/screening` | owner | `{causeOfLoss (1..2000), incidentDate}` | `{status:"screening_updated", message}` | 404, 409 `claim_not_editable` | Draft or Info Needed (Info Needed → Screening) | `claim.screening_updated` | `ClaimsRepository.describe` |
| PUT `/claims/:id/payout-details` | owner | `{claimedAmountCents 1..1e8, bankName, accountHolder, accountNumber ^[0-9]{6,20}$}` | `{status:"payout_details_saved", claimedAmountCents, destination:{bankName, accountLast4}}` | 404, 409 `payout_details_locked` | Draft / Info Needed | `claim.payout_details_set` | `ClaimsRepository.setPayoutDetails` |
| POST `/claims/:id/evidence` | owner | multipart `file` (PDF/JPEG/PNG ≤ 10 MiB; declared type must match bytes) | 201 `{status:"uploaded", evidenceId, sha256}` | 400, 404, 409, 413, 415, 503 | Draft / Info Needed | `evidence.uploaded` / `evidence.rejected` | `ClaimsRepository.uploadEvidence` |
| GET `/claims/:id/evidence` | owner or tenant staff | – | `{evidence:[{id,display_name,mime_type,size_bytes,sha256,created_at}]}` | 404 | – | – | claim detail |
| GET `/claims/:id/evidence/:eid/verify` | owner or tenant staff | – | `{status:"VALID"\|"TAMPERED", evidenceId, expectedHash, actualHash}` | 404 | – | `evidence.integrity_verified` | insurer detail |
| POST `/claims/:id/submit` | owner | – | `{status:"submitted", message, claimId}` | 404, 409, 422 `screening_incomplete` | Draft → Submitted | `claim.stage_changed` | `ClaimsRepository.submit` |
| GET `/claims/:id` | owner, tenant staff (assessor, manager, insurer admin) (not Draft for staff); SUPERADMIN 404 | – | `{claim:{id,policyId,planName,tenantId,insurerName,stage,status,category,causeOfLoss,incidentDate,claimedAmountCents,payoutDestination:null\|{bankName,accountLast4},createdAt,updatedAt,infoRequest:null\|{body,createdAt},appealReason:null\|{body,createdAt}}}` | 404 | – | denied only | `ClaimsRepository.detail` |
| POST `/claims/:id/respond` | CUSTOMER, own claim in Info Needed | `{message 2..2000}` | – | `{status:'sent', stage:'Screening'}`; reply stored with the transition | 400, 404, 409 `not_waiting_for_you` | `claim.stage_changed` | `ClaimsRepository.respond` |
| GET `/claims/:id/messages` | owner, the tenant's staff, its insurer admin (read) | – | – | `{messages:[{id,kind:info_request\|customer_reply\|appeal\|withdraw\|message,authorRole,mine,body,createdAt}]}` | 404 | – | `ClaimsRepository.messages` |
| POST `/claims/:id/messages` | owner, ASSESSOR/MANAGER of the tenant (not Draft) | `{body 2..2000}` | – | 201 `{messages}`; 20 per author per claim per hour | 400, 403, 404, 409, 429 | `claim.message_posted` (never the text) | `ClaimsRepository.postMessage` |
| GET `/claims/:id/timeline` | owner or tenant staff | – | `{claimId, currentStage, timeline:[{stage, date\|null, completed}]}` (6 main stages) | 404 | – | – | claim tracking |
| GET `/claims/:id/decision` | owner or tenant staff | – | `{decision:"Approved"\|"Rejected"\|"pending", record:null\|{id,decidedAt,decidedByRole,reason,approvedAmountCents,rulesVersion,evidenceDigest}}` | 404 | – | – | decision card |
| GET `/claims/:id/decision/verify` | owner or tenant staff | – | `{claimId, decisionId\|null, integrity:{status, alg, keyId, bundleDigest, recomputedDigest}}`; status `VALID`/`TAMPERED`/`UNSIGNED`/`UNKNOWN_KEY`/`UNAVAILABLE`/`NO_DECISION` | 404 | – | `decision.integrity_verified` | integrity card |
| GET `/claims/:id/payout` | owner or tenant staff | – | `{claimId, stage, claimedAmountCents, destination, decision:null\|{id,outcome,approvedAmountCents,decidedAt,decidedByRole}, payout:null\|{id,amountCents,destinationLast4,status,initiatedAt}}` | 404 | – | – | payout card |
| POST `/claims/:id/appeal` | owner | `{reason}` | `{status:"appealed"}` | 404, 409 `not_appealable` | Decision + Rejected → Appeal | `claim.stage_changed` | appeal button |
| POST `/claims/:id/withdraw` | owner | – | `{status:"withdrawn"}` | 404, 409 | any open stage → Withdrawn | `claim.stage_changed` | – |
| GET `/integrity/public-key` | any authenticated | – | `{alg:"ML-DSA-65", standard:"NIST FIPS 204", keyId, bundleVersion, context, publicKey}` | 503 | – | – | not used by the app (outside verifiers) |

Only assessors and managers see risk signals (`/risk-signals` is 403 for customers, insurer admins and superadmins); customers never see another party's data.

## Insurer claim work (ASSESSOR / MANAGER of the claim's tenant; claim not in Draft; otherwise 404)

| Method + path | Role | Request | Response 200 | Errors | Edge | Audit | Frontend |
|---|---|---|---|---|---|---|---|
| POST `/claims/:id/verify` | ASSESSOR, MANAGER | none | `{status:"transitioned", claimId, from, to:"Verified"}` | 403, 404, 409 | Submitted → Verified | `claim.stage_changed` | `InsurerRepository.advance` |
| POST `/claims/:id/screen` | ASSESSOR, MANAGER | none (a body is ignored) | `{..., to:"Screening", riskSignals: RiskSignals\|null}` | same | Verified → Screening | + `screening.signal_attached` | same |
| POST `/claims/:id/review` | ASSESSOR, MANAGER (Appeal → Review: MANAGER) | none | `{..., to:"Review"}` | same | Screening/Appeal → Review | `claim.stage_changed` | same |
| POST `/claims/:id/request-info` | ASSESSOR, MANAGER | none | `{..., to:"Info Needed"}` | same | Screening/Review → Info Needed | same | same |
| GET `/claims/:id/risk-signals` | ASSESSOR, MANAGER | – | `{claimId, stage, riskSignals: RiskSignals\|null}` | 403 customer, 404 | – | `screening.signal_read` | screening card |
| POST `/claims/:id/decide` | **MANAGER** | `{outcome:"Approved"\|"Rejected", reason, approvedAmountCents?}` (no amount on Rejected; omitted = full claimed amount) | `{..., to:"Decision", outcome, decisionId, approvedAmountCents, evidenceCount, evidenceDigest, integrity:{alg,keyId,bundleDigest}}` | 400, 403, 404, 409, 422, 503 `integrity_unavailable` | Review → Decision | `claim.decision_recorded` | `InsurerRepository.decide` |
| POST `/claims/:id/pay` | **MANAGER** | **empty**; optional `Idempotency-Key` | `{status:"paid", simulated:true, claimId, payoutId, decisionId, amountCents, destination}`; replay: `{status:"already_paid", ...}` | 400, 403, 404, 409 | Decision(Approved) → Paid | `payout.completed_simulated` / `payout.blocked` | `InsurerRepository.pay` |

`RiskSignals`:
```
{ classicalAnomaly: 0..1, quantumAnomaly: 0..1, interpretation: NORMAL|UNUSUAL|HIGH_ANOMALY,
  anomalyBand: NORMAL|ELEVATED|HIGH, screeningRecommendation: STANDARD_REVIEW|REVIEW_REQUIRED,
  explanation, versions:{model,features,kernel,screening}, signalDigest, modelVersion,
  execution: simulator|hardware, computedAt, advisory: true }
```
The signal is advisory. It never changes stage, status, eligibility or payout. Only the offline pipeline
(`quantum/`) writes it; no route accepts it.

## Removed stubs (27 Sep 2026; answer 404)

`/client/*`, `GET|PATCH /profile`, `/profile/consent`, `/profile/mandates/*`, `/activities/*`, `/ocr/process`,
`POST /covers/join-request`, `GET /covers/market-catalog`, `GET /claims/status`. Consent and mandates are now real:
see "Consent forms (POPIA)".

## Not in the API (do not call)

`/dashboard`, `/profile/register`, `/profile/login` (removed), `/auth/demo-login` (removed), `/decisions`, `/covers`, `/covers/market`, `GET /claims/:id/risk-signals` for customers. The unmounted `backend/legacy/` code is not an API.

## Flutter stage mapping (`frontend/lib/data/models/claim_stage.dart`)

| Backend `stage` (+ `status`) | App `ClaimStage` | App side state |
|---|---|---|
| Draft | (draft, not on the 6-step bar) | – |
| Submitted, Verified, Screening, Review, Decision, Paid | same | – |
| Info Needed | screening | infoNeeded |
| Decision + Rejected | decision | rejected |
| Appeal | review | appeal |
| Withdrawn, Expired | terminal label | – |

## Scheduled job

Nightly (`wrangler.toml` `[triggers]`): claims left in `Info Needed` for 30 days move to `Expired` (`status` `Closed`)
through the state machine's SYSTEM edge, with a `claim.stage_changed` audit row (`actor_role` `SYSTEM`) per claim.


## Claim hand-offs (migration 0013)

- `POST /claims/:id/request-info` takes an optional `{message}` (the app always sends one). It is stored in
  `claim_messages` in the same batch as the transition, and shown to the customer as `claim.infoRequest`.
- `POST /claims/:id/appeal` now stores `reason`; staff see it as `claim.appealReason`.
- `POST /claims/:id/withdraw` takes an optional `{reason}`.
- Uploading evidence updates `claims.updated_at`, so an active customer is not expired by the Info Needed job.
- `claim_messages` rows are append-only (triggers).

## Consent forms (POPIA, migration 0015)

After the insurer has checked the documents, the customer is sent that insurer's consent / mandate form, signs it
electronically (tick + full name on record + password; ECTA ordinary electronic signature) and the server seals the
signed record with ML-DSA-65 (context `easyclaim/consent/v1`). Work waits for the signature:

- **Onboarding:** documents checked → `POST /tenant/policy-requests/:requestId/consent` → customer signs → approve.
  Approve without a signed form: 409 `consent_required`.
- **Claims:** `POST /claims/:claimId/verify` creates the form in the same batch (`consentRequested: true`). Moving to
  Screening, Review, Decision or Paid (any route, including the customer's `/respond`) needs the latest form to be
  signed: 409 `consent_required`, or `consent_withdrawn` after a withdrawal. Claims past Verified before 0015 have no
  form and are not blocked. `claim.consent` on `GET /claims/:claimId` is the latest form's summary (or null).
- **Withdrawal** (POPIA s11(2)(b)) stops further work until a new form is signed; a withdrawn onboarding form also
  refuses new claims on that policy (`/claims/initiate` 422, audit reason `consent_withdrawn`).
- **Wording** is each insurer's own (`consent_templates`, append-only versions). Version 0 is the built-in EasyClaim
  starter text, used until the insurer saves its own. Placeholders `{{insurer}}`, `{{customer}}`, `{{easyclaimId}}`,
  `{{subject}}`, `{{date}}` are filled in when a form is sent; the rendered text and its SHA-256 are stored with the
  form, so later edits never change a form already sent. Form text, subject and signature cannot be changed and
  forms cannot be deleted (triggers). Free text never goes into `audit_events`.

`Consent` = `{id, subjectType: policy_link|claim, subjectId, status: pending|signed|declined|withdrawn|superseded,
templateVersion, requestedAt, signedName, signedAt, respondedAt, reason, seal: VALID|TAMPERED|UNSIGNED|UNKNOWN_KEY|
UNAVAILABLE|null}`; the detail adds `insurerName, subjectLabel, body, bodySha256` and, for the customer's own pending
form, `signAs` (the name to type).

| Method + path | Request | Response | Errors | Audit | Frontend |
|---|---|---|---|---|---|
| GET `/consents` | CUSTOMER | `{consents:[ConsentDetail]}` own forms | 403 | – | Profile, Home |
| GET `/consents/:consentId` | CUSTOMER | `{consent}` | 404 (not yours) | – | Consent form |
| POST `/consents/:consentId/sign` | `{agree:true, fullName, password}` | `{consent}` signed + sealed | 400 `name_mismatch`/validation, 401 wrong password, 409 `not_pending`/`subject_closed`, 429 after 5 wrong passwords in 15 min, 503 | `consent.sign` success/denied | Consent form |
| POST `/consents/:consentId/decline` | `{reason?}` | `{consent}` | 409 `not_pending` | `consent.decline` | Consent form |
| POST `/consents/:consentId/withdraw` | `{reason?}` | `{consent}` | 409 `not_signed` | `consent.withdraw` | Consent form |
| GET `/claims/:claimId/consent` | owner or the claim's insurer staff | `{consent: ConsentDetail\|null}` | 404 | – | Claim screens |
| POST `/claims/:claimId/consent` | ASSESSOR/MANAGER | 201 `{consent}` (send or re-send) | 409 `consent_already_sent`/`consent_already_signed`/`documents_not_checked` | `consent.requested` | Staff claim screen |
| GET `/tenant/consent-templates` | INSURER_ADMIN | `{onboarding, claim, placeholders}`; template `{kind, version, isStarter, body, updatedAt}` | 403 | – | Consent forms page |
| PUT `/tenant/consent-templates/:kind` | `{body}` 200–20000 chars; kind onboarding\|claim | `{template}` new version | 400, 403 | `consent.template_saved` | Consent forms page |
| POST `/tenant/policy-requests/:requestId/consent` | INSURER_ADMIN | 201 `{consent}` | 404, 409 `documents_incomplete`/`consent_already_sent`/`waiting_for_customer`/`already_decided` | `consent.requested` | Policy requests |
| GET `/tenant/policy-requests/:requestId/consent` | INSURER_ADMIN | `{consent: ConsentDetail\|null}` | 404 | – | Policy requests |

`GET /tenant/policy-requests/:requestId` also returns `readyForConsent` (every document checked, no open form),
`consent` (summary) and `readyToApprove` (documents checked AND form signed).

## Live updates (Durable Object WebSocket, migration 0016)

One live channel per audience: `user:<customerId>` (a customer's devices), `tenant:<tenantId>` (all signed-in staff
of one insurer), `platform` (superadmin). Browsers cannot set headers on a WebSocket, so the app exchanges its token
for a 60-second ticket (own audience: a ticket is not an API token and an API token is not a ticket), then opens
`wss://<api>/api/v1/realtime/connect?ticket=<ticket>`. The connect route checks the ticket, the `Origin`
(ALLOWED_ORIGINS, stops cross-site WebSocket hijacking) and the account (active, same role/insurer, not revoked).

Notices are **change signals only** (ids, stage, status); the app re-fetches through the normal routes, so every
permission check stays server-side. Clients send `ping` (answer `pong`) and re-sync everything on reconnect.

| Event `type` | Fields | Sent to | When |
|---|---|---|---|
| `hello` | `at` | the new socket | on connect |
| `claim.updated` | `claimId, stage` | customer + insurer staff | every stage change (submit, verify, screen, review, info request, reply, decision, pay, appeal, withdraw, expiry) |
| `claim.message` | `claimId, from: customer\|insurer` | both | a message on the claim thread |
| `claim.evidence` | `claimId` | both | evidence uploaded after submission |
| `consent.updated` | `consentId, subjectType, subjectId, status: pending\|viewed\|signed\|declined\|withdrawn` | both | form sent, first opened, signed, declined, withdrawn |
| `link.updated` | `requestId, change: created\|document_uploaded\|resubmitted\|document_checked\|more_info\|approved\|rejected` | both | any policy-link step |
| `team.updated` | `userId, status` | insurer staff + platform | an account enabled/disabled |
| `application.created` | `applicationId` | platform | a new insurer application |
| `session.revoked` | `reason` | only that user's sockets, then closed (code 4001) | account disabled |

| Method + path | Request | Response | Errors | Audit | Frontend |
|---|---|---|---|---|---|
| POST `/realtime/ticket` | bearer token | `{ticket, expiresIn: 60, path}` | 401, 503 `realtime_unavailable` | – | RealtimeService |
| GET `/realtime/connect` | `?ticket=`, `Upgrade: websocket`, allowed `Origin` | 101 WebSocket | 401, 403 `origin_not_allowed`, 426 | – | RealtimeService |

Also new: consent summaries carry `viewedAt` (first open by the customer; `GET /consents/:consentId` records it and
audits `consent.viewed`); `GET /claims` rows carry `consent_status` and `consent_viewed_at`; policy-link rows carry
`consentStatus` and `consentViewedAt`; `GET /tenant/overview` adds `attention: {awaitingMandate, mandateOpened,
mandateDeclined, consentWithdrawn, infoNeeded, newClaims}`; `POST /claims/:claimId/consent` is also allowed for
INSURER_ADMIN (sending a form is a communication; the admin still cannot move a claim); the tenant audit feed now
includes customers' actions on the insurer's consent forms and policy-link requests.
