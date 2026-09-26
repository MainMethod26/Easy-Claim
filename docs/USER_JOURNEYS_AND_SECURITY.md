# EasyClaim: user journeys and where the cyber controls sit

For the whole team (product, backend, cyber, quantum). Everything here is on `main` as of 2026-09-26 (Phases 0–4
merged) and verified by `npm test` (228 tests, 15 files). Status words: IMPLEMENTED · PARTIAL · PLANNED · DECISION REQUIRED.
Deeper detail: `docs/phase-reports/PHASE_0N_REPORT.md`, `docs/security/*`, `docs/team-brief/`.

## 1. The cast

| Actor | Who they are | How the API knows | What they may touch |
|---|---|---|---|
| **Customer** (`CUSTOMER`) | A policyholder. Platform-level: one customer can hold policies with several insurers | Bearer JWT, no `tenant_id` | Only their own claims (`claims.user_id`), only while the claim is theirs to edit |
| **Assessor** (`ASSESSOR`) | Insurer staff who prepare a claim | Bearer JWT with `tenant_id` | Submitted claims of their own insurer: verify, screen, review, request info, read evidence |
| **Manager** (`MANAGER`) | Insurer staff who decide and pay | Bearer JWT with `tenant_id` | Same as assessor, plus decide and pay |
| **Admin** (`ADMIN`) | Reserved for configuration | Bearer JWT, `tenant_id` optional | No claim access at all (DECISION REQUIRED: platform vs tenant admin) |
| Attacker | Anyone with a forged/stolen token, another customer, staff of another insurer, or someone with database access | — | Blocked at one of the six gates below; every refusal is audited |

Tenants = insurers (`ins_discovery`, `ins_sanlam`, …). A claim belongs to the insurer that underwrites the policy it was
filed against (`claims.tenant_id`, copied from the policy, never from the client).

## 2. The six gates every request crosses

```
Bearer JWT ──► 1 requireActor        verified signature, issuer, audience, expiry, role/tenant rules      → 401
           ──► 2 requireRole         coarse, resource-independent role gate                               → 403
           ──► 3 strict zod schema   unknown / privileged fields (stage, status, amount, tenantId…)       → 400
           ──► 4 loadAuthorizedClaim tenant boundary + ownership + "drafts are private"                    → 404 (same as "no such claim")
           ──► 5 transitionClaim     state machine incl. who may perform the edge; one D1 batch           → 409 / 403
           ──► 6 audit_events        append-only row for the change AND for every refusal                 (triggers block UPDATE/DELETE)
```
Plus, around them: per-IP rate limit before the token check, per-actor rate limit after it, 64 KB JSON body limit,
security headers, CORS allowlist, generic error bodies, server-generated request ids.

## 3. Customer journey

| Step | What the customer does | Endpoint | Gates that matter | What the system records |
|---|---|---|---|---|
| Sign in | Obtains a bearer token (local demo: `npm run token`; real IdP PLANNED) | — | 1 | — |
| See covers | Lists own policies | `GET /covers/my-covers` | 1, 2 | — |
| Start a claim | Picks one of **their own, active** policies | `POST /claims/initiate` | 1, 2, 3, ownership of the policy | `claim.created`; claim is `Draft`, `tenant_id` set from the policy |
| Describe the loss | Cause of loss, incident date | `PATCH /claims/:id/screening` | 1–4 (owner-write, only Draft / Info Needed) | `claim.screening_updated` |
| Say what they claim and where to pay | Claimed amount, bank, account holder, account number | `PUT /claims/:id/payout-details` (Phase 3) | 1–4; only Draft / Info Needed; account number stored as SHA-256 + last 4 | `claim.payout_details_set` |
| Attach evidence | PDF/JPEG/PNG up to 10 MB; declared type must match the file's magic bytes | `POST /claims/:id/evidence` (Phase 2) | 1–4; private R2 storage, server-generated key, SHA-256 per file | `evidence.uploaded` / `evidence.rejected` |
| Submit | Locks the claim: narrative, amount, destination and evidence are now frozen | `POST /claims/:id/submit` | 1–5 (`Draft → Submitted`) | `claim.stage_changed` |
| Follow progress | Timeline, decision, money view, evidence list | `GET /claims/:id/timeline`, `/decision`, `/payout`, `/evidence` | 1, 4 (read) | reads are not audited; evidence downloads are |
| Answer an information request | Insurer sent the claim to Info Needed; customer edits and it returns to Screening | `PATCH /claims/:id/screening` | 1–5 (`Info Needed → Screening`) | `claim.stage_changed` |
| Appeal a rejection | Once, from `Decision/Rejected` | `POST /claims/:id/appeal` | 1–5 (`Decision → Appeal`) | `claim.stage_changed` (appeal limit DECISION REQUIRED) |

What a customer **cannot** do, by design: read or touch another customer's claim (404), set `stage`/`status`/`amount`
directly (400), change the payout destination after submission (409, audited), decide or pay (403), see another
tenant's or a non-existent claim differently from each other.

## 4. Insurer journey (assessor then manager, same tenant)

| Step | Who | Endpoint | Edge | Gates that matter | Recorded |
|---|---|---|---|---|---|
| Work queue | Assessor / Manager | `GET /claims` | — | 1, 2, 4 (own tenant only; drafts hidden; no `user_id` exposed) | — |
| Look at the file | Assessor / Manager | `GET /claims/:id/timeline`, `/risk-signals` (audited `screening.signal_read`), `/evidence`, `/evidence/:eid`, `/evidence/:eid/verify`, `/payout` | — | 1, 4 (own tenant); `verify` re-hashes the stored object → `VALID` / `TAMPERED` | `evidence.accessed`, `evidence.integrity_verified` |
| Verify identity/policy | Assessor | `POST /claims/:id/verify` | `Submitted → Verified` | 1–6 | `claim.stage_changed` |
| Screen | Assessor | `POST /claims/:id/screen` | `Verified → Screening` | 1–6; Phase 4 attaches the advisory signal **read-only** after the transition: classical + quantum scores, band NORMAL / ELEVATED / HIGH, recommendation STANDARD_REVIEW / REVIEW_REQUIRED, versions, digest | `claim.stage_changed`, `screening.signal_attached` (with digest) |
| Ask the customer for more | Assessor | `POST /claims/:id/request-info` | `Screening/Review → Info Needed` | 1–6 | `claim.stage_changed` |
| Review | Assessor | `POST /claims/:id/review` | `Screening → Review` | 1–6 | `claim.stage_changed` |
| Decide | **Manager only** | `POST /claims/:id/decide` `{ outcome, reason, approvedAmountCents? }` | `Review → Decision` | 1–6 + business checks: approval needs payout details, approved ≤ claimed | insert-only `claim_decisions` row (who, when, why, previous stage, amounts, destination snapshot, **evidence digest**, **screening signal it saw**, rules version), **signed with ML-DSA-65** (Phase 5) + `claim.decision_recorded` |
| Pay | **Manager only** | `POST /claims/:id/pay` (no body; optional `Idempotency-Key`) | `Decision → Paid` | 1–6 + amount from the decision, destination must still match the snapshot, one payout per claim | insert-only `payouts` row (`status = simulated`) + `payout.completed_simulated` |
| Re-review an appeal | Manager | `POST /claims/:id/review` | `Appeal → Review` | 1–6 | `claim.stage_changed` |

Assessors deliberately cannot decide or pay (Phase 3 resolved that question). The same manager may today both decide
and pay — separation of duties is DECISION REQUIRED (`BACKEND-SEC-015`). Withdrawn and Expired exist in the state
machine but have no endpoint or job yet.

## 5. Attacker journeys and what stops them

| Attack | Where it hits | Result | Proof |
|---|---|---|---|
| Forged / expired / tampered / `alg=none` token, dev headers | Gate 1 | 401, nothing logged but the error class | `test/auth.test.ts`, Phase 1 live log |
| Customer B reads or edits customer A's claim | Gate 4 | 404, identical to "no such claim", audited `not_owner` | `test/bola.test.ts` |
| Sanlam staff read, decide or pay a Discovery claim | Gate 4 | 404, audited `cross_tenant` | `test/tenant.test.ts`, Phase 3 live log |
| Customer or assessor approves a claim | Gates 2 / 5 | 403, audited | `test/decisionPayout.test.ts` P3-01/02 |
| `{"stage":"Paid"}` or `{"amount":…}` in any request | Gate 3 | 400 `unrecognized_keys` / `client_supplied_fields`, audited | P3-03, P3-05 |
| Pay a claim that was never decided (`Submitted → Paid`) | Gate 5 | 409 `illegal_transition`, audited | P3-04 |
| Approve R420 000 on a R4 200 claim | Business check at decision | 422 `amount_exceeds_claimed`, audited | P3-05 |
| Change the bank account after approval, even directly in the database | Destination lock + decision snapshot | 409 `payout_details_locked` / `destination_mismatch`, no payout | P3-06 |
| Pay twice (replay, retry storm) | `payouts.claim_id UNIQUE` + state machine | 409 `already_paid`; same `Idempotency-Key` → same payout, one row | P3-08 |
| Upload an `.exe` renamed `.pdf`, an 11 MB file, or against someone else's claim | Evidence validation + Gate 4 | 415 / 413 / 404 | `test/evidence.test.ts` |
| Swap the bytes of stored evidence | Integrity check | `verify` reports `TAMPERED`; the decision's evidence digest no longer recomputes | Phase 2 tests + `claim_decisions.evidence_digest` |
| Edit a recorded decision directly in the database (amount, destination, outcome, evidence, screening) | ML-DSA-65 signature over the decision bundle (Phase 5) | `decision/verify` → TAMPERED; `/pay` 409 `decision_integrity_failed` | `test/decisionIntegrity.test.ts`, Phase 5 live log |
| Rewrite or delete decision, payout or audit history | Database triggers, no write routes | rejected at the database; routes 404 | P3-09, `test/audit.test.ts` |
| A client supplies a quantum/anomaly score, or tries to turn a HIGH signal into Paid/Rejected | No write route; strict bodies; signal read after the transition | 400 / 404 / 409; signal digest audited and stored in the decision | `test/quantumScreening.test.ts` |
| Prompt injection in a document or queue message | Queue validation; OCR/AI is advisory only | discarded / logged; no code path to claim state | `test/queue.test.ts` |
| One credential hammering the API | Per-actor rate limit | 429 | `test/hardening.test.ts` |

## 6. How the pieces fit (data)

```
policies ─┐                                  evidence (Phase 2): per-file SHA-256, private R2 key, tenant_id
          ├─► claims: stage, status, tenant_id, claimed_amount_cents, payout_* (hash + last 4)
tenants ──┘        │
                   ├─► claim_decisions (Phase 3, insert-only): outcome, reason, amounts, destination_hash,
                   │        evidence_digest ◄── SHA-256 over the claim's evidence hashes at decision time
                   │        risk_signal (Phase 4, advisory), integrity_signature (Phase 5, planned ML-DSA)
                   ├─► payouts (Phase 3, insert-only, one per claim, simulated)
                   └─► screening_signals (Phase 4, read-only quantum/classical anomaly signal)
audit_events (Phase 0, append-only): every change and every refusal, with actor, role, tenant, request id
```

## 7. What is still open (cyber)

Real identity provider, key rotation, revocation (`BACKEND-SEC-019`) · per-environment config (`018`) · separation of
duties (`015`) · appeal limit (`016`) · claimant reference for insurers instead of `user_id` (`017`) · ADMIN scope (`020`)
· OCR engine and its trust boundary (`008`) · configuration audit (`009`) · demo stubs (`/profile`, `/client/*`,
`/activities/*`) still return fixed data (`010`) · the unmounted MVC layer must stay unmounted until guarded (`021`) ·
Phase 5 ML-DSA signature over the decision record (column reserved).
