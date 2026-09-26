# EasyClaim Phase 3 Report — Decision + Payout Security

Date: 2026-09-26 · Branch: `phase-3-decision-payout` (worktree `ec-merged`, based on `origin/cyber` @ `0e75d6a`) · **Uncommitted** (see §12 and the delivery message)
Status words: IMPLEMENTED + TESTED · IMPLEMENTED + NOT FULLY TESTED · PARTIAL · PLANNED · BLOCKED · DECISION REQUIRED.

## 1. Objective
Protect the most sensitive point of the lifecycle — Review → Decision → Payout — so that **the client never defines the authoritative decision or payout state**: only an authorized decision-maker decides, every decision is recorded and reconstructable, the payout amount and destination come from server-held data, a payout happens at most once, and every sensitive action or refusal is audited. Kept deliberately small: the payout is simulated; no money moves.

## 2. Starting state (`docs/phase-reports/PHASE_03_PRECHECK.md`)
Phase 0 and Phase 1 complete and verified on `0e75d6a` (183 tests); Phase 2 (evidence) NOT AVAILABLE — in progress by a teammate, so decisions cannot yet be bound to evidence hashes (a nullable `evidence_digest` column is reserved). Before Phase 3: `/decide` accepted only `{ outcome }` from ASSESSOR **or** MANAGER and wrote `claims.status`; no decision record, no amount, no destination; `/pay` was a bare MANAGER-only state transition.

## 3. Implemented controls
| Control | Where | Status |
|---|---|---|
| Decision is MANAGER-only; customers and assessors refused | `src/security/claimStateMachine.ts` (`Review → Decision: MANAGER_ONLY`), `requireRole` gate in `src/endpoints/claimsInsurer.ts` | IMPLEMENTED + TESTED |
| Insert-only decision record with actor, role, timestamp, reason, previous stage, claimed/approved amounts, destination snapshot, request id, rules version | `migrations/0005_decisions_payouts.sql` (`claim_decisions` + no-update/no-delete triggers), `POST /claims/:id/decide` | IMPLEMENTED + TESTED |
| Decision row written atomically with the stage change | `transitionClaim(..., { extra })` + `gatedInsert()` (`INSERT … SELECT … WHERE changes() = 1`) in `src/security/ledger.ts` | IMPLEMENTED + TESTED |
| Customer supplies claimed amount + payout destination only while Draft / Info Needed; account number stored as SHA-256 + last 4 | `PUT /claims/:id/payout-details` (`src/endpoints/claims.ts`), claim columns in 0005 | IMPLEMENTED + TESTED |
| Approved amount ≤ claimed amount, defaults to claimed; amount on a rejection refused | `/decide` business validation | IMPLEMENTED + TESTED |
| `/pay` accepts no body; any client field (amount, destination, state) → 400 + audit | `/pay` body guard (`emptyBodySchema`) | IMPLEMENTED + TESTED |
| Payout amount = recorded approved amount; destination must still hash to the decision-time snapshot | `/pay` business validation, `payouts` row | IMPLEMENTED + TESTED |
| Destination frozen after submission; change attempts audited; DB-level tamper caught at payout | `payout-details` lock, `destination_mismatch` check | IMPLEMENTED + TESTED |
| One payout per claim (`payouts.claim_id UNIQUE`, state machine) + optional `Idempotency-Key` replay | `/pay`, `migrations/0005` | IMPLEMENTED + TESTED |
| Sensitive-action audit: decision recorded/rejected, payout blocked/completed/replayed, destination change blocked, role and cross-tenant denials | `writeAuditEvent` calls; actions listed in §7 | IMPLEMENTED + TESTED |
| Masked money view for owner / tenant staff | `GET /claims/:id/payout`, `GET /claims/:id/decision` (now returns the record) | IMPLEMENTED + TESTED |

## 4. Decision authorization
Existing chain, unchanged in shape: `requireActor` → `requireRole('ASSESSOR','MANAGER')` (coarse) → strict body → `loadAuthorizedClaim(…, 'insurer')` (tenant, 404 on deny) → `checkTransition(Review → Decision, role)` → business validation → `transitionClaim`. CUSTOMER → 403 (`authz.role_denied`), ASSESSOR → 403 (`claim.transition_rejected: role_not_permitted`), other tenant's MANAGER → 404 (`authz.claim_access_denied: cross_tenant`). Resolves the Phase 1 DECISION REQUIRED item "may assessors decide?" as **no** (assessors prepare, managers decide and pay). No new roles.

## 5. State protection
All decision/payout state changes go through `transitionClaim` (the only stage writer; verified by grep). Clients cannot post a state: `state`/`stage`/`status` fields are rejected by the strict schemas on every route (400); there is no generic transition route (404); `Submitted → Paid` and `Review → Paid` are refused by the state machine (409 `illegal_transition`, audited). Concurrent decisions on one claim yield exactly one decision row (gated insert in the same batch as the conditional UPDATE).

## 6. Payout protection
Simulated only (`payouts.status = 'simulated'`). Amount: never read from the request; `/pay` with any body is refused (400 `client_supplied_fields`, audited `payout.blocked`); the paid amount is `claim_decisions.approved_amount_cents`, which the decision capped at the customer's claimed amount (422 `amount_exceeds_claimed` otherwise). Destination: captured before submission, frozen afterwards (409 `payout_details_locked`, audited `payout.destination_change_blocked`); the decision snapshots its hash and `/pay` refuses on mismatch (409 `destination_mismatch`, audited) — so even a direct database change of the destination after approval cannot be paid. Replay: `payouts.claim_id UNIQUE` + state machine (`Paid` has no outgoing edge) → second request 409 `already_paid`; an identical `Idempotency-Key` returns the same payout (200 `already_paid`, audited `payout.replayed_idempotent`); three concurrent requests produce one row. Authorization: MANAGER of the claim's tenant only (assessor 403, customer 403, other tenant 404). Legacy approvals without a decision record (seed `claim_sanlam_102`) cannot be paid (409 `decision_record_missing`).

## 7. Audit behaviour
Existing append-only `audit_events` (Phase 0 triggers) plus two new insert-only ledgers with the same triggers. New actions: `claim.decision_recorded`, `claim.decision_rejected` (reasons `payout_details_missing`, `amount_exceeds_claimed`, `amount_not_allowed_for_rejection`), `claim.payout_details_set`, `payout.destination_change_blocked`, `payout.blocked` (reasons `client_supplied_fields`, `invalid_idempotency_key`, `already_paid`, `not_approved`, `decision_record_missing`, `amount_missing`, `destination_mismatch`), `payout.completed_simulated`, `payout.replayed_idempotent`; plus the existing `claim.stage_changed` rows now carry `decisionId` / `payoutId` / amounts. Audit details hold identifiers, amounts and reason codes only — the free-text rationale lives in `claim_decisions.reason`, the account number nowhere (hash + last 4). No route updates or deletes any of the three tables (verified: UPDATE/DELETE raise `append-only`; DELETE/PATCH on decision/payout/audit paths → 404).

## 8. Attack scenarios
Automated: `test/decisionPayout.test.ts`. Live: `docs/phase-reports/evidence/PHASE_03_LIVE_DEMOS.log` (script `evidence/live-demos-p3.sh`).

| # | Attack | Expected | Result | Evidence |
|---|---|---|---|---|
| 1 | Customer approves claim | 403 | `403 forbidden`, `authz.role_denied` | P3-01, DEMO 1 |
| 2 | Assessor (unauthorized insurer role) decides | 403 | `403`, `claim.transition_rejected role_not_permitted` | P3-02, DEMO 1 |
| 3 | Client submits arbitrary state (`state: 'Paid'` on screening / payout-details / decide; generic transition route) | 400 / 404 | `400 unrecognized_keys`, `404` | P3-03, DEMO 2 |
| 4 | Submitted → Paid | 409 | `409 illegal_transition`, audited | P3-04, DEMO 2 |
| 5 | Payout amount R420 000 on a R4 200 claim (at decision, and as `/pay` body) | 422 / 400 | `422 amount_exceeds_claimed`; `400 client_supplied_fields` + `payout.blocked`; real payout = 420 000 c | P3-05, DEMO 3 |
| 6 | Destination changed after approval (owner, other customer, direct DB tamper) | 409 / 404 / 409 | `409 payout_details_locked`; `404`; `409 destination_mismatch`, no payout row | P3-06, DEMO 4 |
| 7 | Cross-tenant manager decides / pays | 404 | `404 not_found`, stage unchanged | P3-07a/b, DEMO 1 & 5 |
| 8 | Duplicate payout (plain, other key, same key, 3× concurrent) | 409 / 409 / 200 same payout / one row | as expected | P3-08, concurrency test, DEMO 5 |
| 9 | History manipulation (UPDATE/DELETE on decisions, payouts, audit; write routes) | refused | `append-only` abort; routes 404 | P3-09 |
| 10 | Valid authorized decision | 200 + record | recorded with actor/time/reason/amounts/snapshot | P3-10, DEMO 5 |
| 11 | Valid payout after legitimate decision | 200 simulated | paid 420 000 c to last4 7890, stage Paid | P3-11, DEMO 5 |
| 12 | Decision and payout generate audit events | verified | full trail incl. denials (see log) | P3-12, DEMO 5 |

## 9. Test results (`npm test`, `npm run typecheck`, `npm audit` on this branch)
- Test files 13 passed; **206 passed, 1 todo (207)**. Phase 0 suites (bola, rbac, massAssignment, claimLifecycle, hardening, audit, queue, stateMachine): all pass; Phase 1 suites (actor, auth, tenant, migration): all pass; Phase 3 (`decisionPayout.test.ts`): 23 tests pass. Phase 2: no suite exists on this branch.
- Changes to existing tests: `stateMachine.test.ts` now expects ASSESSOR → Decision to be refused; `tenant.test.ts` decide calls carry a `reason`; `helpers.ts` gives every generated claim payout details and bypasses the global rate limiter for functional tests (hardening tests still exercise the limiter with their own stub).
- `tsc --noEmit` exit 0. Build: no separate build step exists (`wrangler dev` bundles); `wrangler dev` started and served the demos. `npm audit`: **2 high (`marked <= 4.0.9`)** — pre-existing on `origin/cyber` from the backend team's OpenAPI tooling, unrelated to Phase 3 and not fixed here.
- A vitest "EnvironmentTeardownError … Closing rpc" line appears at the end of the run; it is worker-shutdown noise, not a test failure.

## 10. Known limitations
- Payout is simulated: no payment rail, no settlement, no reconciliation; `payouts.status` is always `simulated`.
- Amount authority is the customer's claimed amount capped by the manager; there is no policy-limit or tariff lookup (`policies` has no cover amount). The decision-maker is trusted for the amount up to the claim.
- Destination protection is freeze + snapshot; there is no step-up authentication or second approver for a legitimate destination change (a customer must Withdraw/re-file, and Withdrawn has no endpoint yet).
- Separation of duties is not enforced: the same MANAGER may decide and pay (DECISION REQUIRED since Phase 1).
- Legacy approvals without a decision record can never be paid (by design; migrate them by recording a decision).
- `Idempotency-Key` is per claim, not a global key store; a different key after a payout is a 409, not a new payout.
- Evidence binding (`evidence_digest`), risk signal and integrity signature columns exist but are NULL until Phase 2 / a later phase fills them.

## 11. Deferred work
Phase 2 evidence digest into decisions; ML-DSA/PQC signature of the decision record (`integrity_signature` reserved; the record is already a stable, insert-only structure to sign); quantum/risk screening as an advisory `risk_signal` (must never call `transitionClaim`); separation of duties and appeal limits (business decisions); policy cover limits; real payment integration with destination verification and step-up auth; per-environment config and the `marked` upgrade (backend team).

## 12. Demo instructions
```bash
npm install && npm run setup:local && npm run db:migrate:local && npm run db:seed:local && npm run dev
npm run token -- --postman     # tokens for Postman; import postman/EasyClaim.local.postman_environment.json
```
Postman folders 1 → 2 → 3 walk the legitimate flow (initiate → payout details → screening → submit → verify → screen → review → decide → pay); folder **8 "Phase 3 decision & payout attacks"** holds DEMO 1–5. Or run everything at once: `bash docs/phase-reports/evidence/live-demos-p3.sh` against a running dev server on port 8788.

## 13. Post-rebase note: security regression found on `main` and restored here
Rebasing onto `main` (`d76a0c6`, backend team) showed that its rewritten `src/index.ts` mounted the unsecured MVC `routes/*`
instead of `endpoints/*`, dropped `requireActor`, both rate limits, security headers, CORS, the body limit, the error handler and
the queue consumer, and imported an undeclared `@hono/swagger-ui` — so on `main` the API was unauthenticated and no test file
could load. With the user's approval this branch **restores the Phase 0–3 pipeline in `src/index.ts`**, keeps the team's
`/swagger` and `/openapi.json` routes (adds `@hono/swagger-ui`, `resolveJsonModule`), and leaves the MVC layer in the repo but
unmounted, as `docs/PARALLEL_WORK.md` requires. Commit: `fix(security): restore authentication pipeline in index.ts`.

Git: committed on `phase-3-decision-payout` (rebased on `main`) and pushed for a PR to `main`; not merged.
