# Security Test Plan

Run automated tests:

```bash
cd backend
npm install
npm test            # 9 files, 85 tests — all TESTED/PASSED on branch cyber
```

Manual tests use the local server (`npm run db:migrate:local && npm run db:seed:local && npm run dev`) at `http://127.0.0.1:8787` with `ALLOW_DEV_ACTOR_HEADERS=true` in `backend/.dev.vars`.

Seed actors: `user123` (CUSTOMER, owns `claim_disc_101` in Review and `claim_sanlam_102` in Decision/Approved), `user456` (CUSTOMER, owns no claims), any id with role ASSESSOR / MANAGER / ADMIN.

Status vocabulary: TESTED/PASSED · TESTED/FAILED · NOT TESTED · BLOCKED (feature missing).

## Authentication

| ID | Test | Method | Status |
|---|---|---|---|
| AUTHN-01 | No credentials → 401 | `test/actor.test.ts` "401 when no actor headers are sent" | TESTED/PASSED |
| AUTHN-02 | Dev headers ignored when flag off → 401 | `test/actor.test.ts` "401 when the dev flag is off…" | TESTED/PASSED |
| AUTHN-03 | Invalid role → 401 | `test/actor.test.ts` "401 for an unknown role" | TESTED/PASSED |
| AUTHN-04 | Malformed actor id (SQL-like) → 401 | `test/actor.test.ts` "401 for a malformed actor id" | TESTED/PASSED |
| AUTHN-05 | Every route (`/client/home`, `/covers/market-catalog`, `/claims/status`, `/profile`, `/activities/*`) requires actor | `test/actor.test.ts` "%s requires an actor" | TESTED/PASSED |
| AUTHN-06 | Invalid credentials | — | BLOCKED (no auth; backend team) |
| AUTHN-07 | Expired token | — | BLOCKED (no auth) |
| AUTHN-08 | Bad signature / `alg:none` token | — | BLOCKED (no auth) |
| AUTHN-09 | Brute-force login throttled | — | BLOCKED (no login) |

## Authorization

| ID | Test | Method | Status |
|---|---|---|---|
| AUTHZ-01 | Customer B reads A's timeline → 404, no data leaked | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-02 | Customer B reads A's decision → 404 | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-03 | Customer B submits/screens/uploads/appeals A's claim → 404 | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-04 | Denied vs non-existent claim responses identical | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-05 | Denied access writes `authz.claim_access_denied` | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-06 | `my-covers` returns only caller's policies | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-07 | Cannot initiate claim on another's policy → 422 | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-08 | `verify-eligibility` does not confirm another's policy | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-09 | Customer → insurer function `/ocr/process` → 403 + audit | `test/rbac.test.ts` | TESTED/PASSED |
| AUTHZ-10 | Insurer roles blocked from customer-only routes → 403 | `test/rbac.test.ts` | TESTED/PASSED |
| AUTHZ-11 | ADMIN cannot read claims | `test/rbac.test.ts` | TESTED/PASSED |
| AUTHZ-12 | Assessor can read but not act as customer | `test/bola.test.ts` | TESTED/PASSED |
| AUTHZ-13 | Assessor accessing admin functionality | — | BLOCKED (no admin endpoints) |
| AUTHZ-14 | Unauthorized configuration change | — | BLOCKED (no config endpoints) |
| AUTHZ-15 | Assessor of insurer X reads claim of insurer Y | — | BLOCKED (no tenant model) |

## Object property (mass assignment)

| ID | Test | Method | Status |
|---|---|---|---|
| PROP-01..06 | Screening with `stage`, `status`, `riskScore`, `decision`, `approvedBy`, `user_id` → 400, row unchanged | `test/massAssignment.test.ts` | TESTED/PASSED |
| PROP-07 | Initiate with `stage`/`userId` → 400 | `test/massAssignment.test.ts` | TESTED/PASSED |
| PROP-08 | Join-request with `userId` → 400; body not echoed | `test/massAssignment.test.ts` | TESTED/PASSED |
| PROP-09 | Validation error does not echo input | `test/massAssignment.test.ts` | TESTED/PASSED |

## State machine

| ID | Test | Method | Status |
|---|---|---|---|
| STATE-01 | 12 legal transitions allowed | `test/stateMachine.test.ts` | TESTED/PASSED |
| STATE-02 | Illegal: Submitted→Paid, Screening→Paid, Screening→Decision (skip review), Verified→Review (skip screening), terminal states | `test/stateMachine.test.ts` | TESTED/PASSED |
| STATE-03 | Role: Customer→Decision, Customer→Paid, Assessor→Paid, Admin→any rejected | `test/stateMachine.test.ts` | TESTED/PASSED |
| STATE-04 | Only MANAGER can reach Paid; ADMIN in no transition | `test/stateMachine.test.ts` | TESTED/PASSED |
| STATE-05 | Initiate→screening→submit via API, audited, timeline dated | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-06 | Submit before screening → 422 | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-07 | Double submit (replay) → 409 + `claim.transition_rejected` | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-08 | Claim in Review cannot be resubmitted/edited → 409 | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-09 | Approved decision not appealable; rejected appealable once | `test/claimLifecycle.test.ts` | TESTED/PASSED |
| STATE-10 | Unauthorized payout via API | — | BLOCKED (no payout endpoint) |

## Evidence

| ID | Test | Status |
|---|---|---|
| EVID-01 | Evidence event on another's claim → 404 | TESTED/PASSED (`test/bola.test.ts`) |
| EVID-02..06 | Oversized upload, invalid type, path traversal filename, replacement, cross-customer download | BLOCKED — no file upload/storage exists |

## Resource abuse

| ID | Test | Method | Status |
|---|---|---|---|
| RATE-01 | Limiter denial → 429 | `test/hardening.test.ts` | TESTED/PASSED |
| RATE-02 | Binding configured | `test/hardening.test.ts` | TESTED/PASSED |
| RATE-03 | 120 rapid requests locally → some 429 | Manual curl loop (observed 113×200, 7×429) | TESTED/PASSED |
| RATE-04 | Body > 64 KB → 413 | `test/hardening.test.ts` | TESTED/PASSED |
| RATE-05 | Excessive pagination | NOT TESTED — no paginated endpoints |

## Hardening / leakage

| ID | Test | Method | Status |
|---|---|---|---|
| HARD-01 | Security headers present | `test/hardening.test.ts` | TESTED/PASSED |
| HARD-02 | CORS allows only configured origin | `test/hardening.test.ts` | TESTED/PASSED |
| HARD-03 | Unknown route → JSON 404 | `test/hardening.test.ts` | TESTED/PASSED |
| HARD-04 | Malformed JSON → 400 | `test/hardening.test.ts` | TESTED/PASSED |
| HARD-05 | Internal error → generic 500, no stack/SQL | `test/hardening.test.ts` | TESTED/PASSED |

## AI / OCR

| ID | Test | Status |
|---|---|---|
| AI-01 | Malformed / prompt-like queue message discarded, not retried | TESTED/PASSED (`test/queue.test.ts`) |
| AI-02..04 | Malicious document text, prompt injection in OCR output, AI overriding rules | BLOCKED — no OCR/AI |

## Audit

| ID | Test | Status |
|---|---|---|
| AUD-01 | Sensitive actions produce events (created, stage_changed, transition_rejected, access_denied, role_denied) | TESTED/PASSED (`test/claimLifecycle.test.ts`, `test/bola.test.ts`, `test/rbac.test.ts`) |
| AUD-02 | Audit rows cannot be updated/deleted | TESTED/PASSED (`test/audit.test.ts`) |
| AUD-03 | No narratives or dev headers in audit rows | TESTED/PASSED (`test/audit.test.ts`) |
| AUD-04 | Every row has actor, action, outcome, request id | TESTED/PASSED (`test/audit.test.ts`) |
| AUD-05 | Secrets not in app logs | NOT TESTED (manual review of `console.*` calls only) |

## Test quality check

A mutation (forcing `allowed = true` in `loadAuthorizedClaim`) made 5 tests in `test/bola.test.ts` fail; the check was reverted.
