# Phase 3 Precheck: Decision + Payout Security

Date: 2026-09-26 · Base: `origin/cyber` @ `0e75d6a` ("merge: update phase 1 branch with latest main") · Work branch: `phase-3-decision-payout` (worktree `ec-merged`)
Method: read-only inspection of the merged tree; diffs against the Phase 1 commit `cb2588a`; `npm test` / `npm run typecheck` / `npm audit` re-run on `0e75d6a`.

## 1. Phase 0 status — COMPLETE (verified)
Security baseline present at the repo root (`src/security/*`, `migrations/0001`, `0002`), 85 Phase 0 tests still in the suite and passing. Docs: `docs/security/*`, `docs/BACKEND_INVENTORY.md`.

## 2. Phase 1 status — COMPLETE (verified); documentation partly uncommitted
Bearer-JWT authentication (`src/security/actor.ts`), tenant model (`migrations/0003_tenants.sql`), insurer routes (`src/endpoints/claimsInsurer.ts`), 183 tests. Every Phase 1 source, migration and test file on `0e75d6a` is byte-identical to `cb2588a` (only moved from `backend/` to the root by commit `604bf9a`). The Phase 1 report and 19 revised docs exist only as **uncommitted edits in the main checkout** (`Easy-Claim/`, still at `cb2588a`); they are not on this branch. `docs/phase-reports/PHASE_01_REPORT.md` is therefore absent here; its content is summarised in this precheck where needed.

## 3. Phase 2 status — NOT AVAILABLE (in progress by a teammate, not pushed)
No evidence upload, storage, hashing or OCR code exists on `0e75d6a`; `POST /claims/:claimId/evidence-ocr` still only queues an event; the `evidence` table (0002) is unused. **Phase 3 therefore cannot bind decisions to evidence hashes yet** — a nullable `evidence_digest` column is reserved on the decision record for Phase 2 to fill.

## 4. Current decision functionality
- `POST /api/v1/claims/:claimId/decide` `{ outcome: 'Approved' | 'Rejected' }` (strict) — ASSESSOR **or** MANAGER of the claim's tenant, `Review → Decision` via `transitionClaim`, outcome written to `claims.status` in the same statement. No reason, no amount, no decision record, no snapshot of what was decided on.
- `GET /api/v1/claims/:claimId/decision` returns `claims.status` when stage is Decision/Paid, else `pending`.
- Seed claim `claim_sanlam_102` sits in Decision/Approved with no decision record.

## 5. Current payout functionality
- `POST /api/v1/claims/:claimId/pay` — MANAGER only (state machine `Decision → Paid`), requires `claims.status = 'Approved'`, is a **state transition only**: no amount, no destination, no payout record, no idempotency key. A second call is refused by the state machine (`Paid` has no outgoing edge) — that is the only replay protection.
- No payout amount exists anywhere (no `amount` column on claims or policies). No bank/destination data exists (`schema.sql` at the root sketches a `mandates` table but is not a migration and is not applied).

## 6. Existing authorization controls (reusable as-is)
`requireActor` (verified JWT) → `requireRole` (coarse, resource-independent) → strict zod → `loadAuthorizedClaim(c, id, 'read' | 'owner-write' | 'insurer')` (tenant boundary, ownership, drafts hidden; 404 + audit on deny) → `transitionClaim` (owner/tenant re-check, state machine incl. per-edge role, one D1 batch). Roles: CUSTOMER, ASSESSOR, MANAGER, ADMIN (`src/types.ts`).

## 7. Existing audit controls
`audit_events` insert-only (UPDATE/DELETE triggers, `migrations/0002`), rows carry actor id/role/tenant, server-generated request id, `details` JSON; `auditStatement(..., { onlyIfPreviousChanged })` lets an audit INSERT be gated on the previous statement in a batch having changed one row (`WHERE changes() = 1`). Actions today: `claim.created`, `claim.screening_updated`, `claim.evidence_queued`, `claim.stage_changed`, `claim.transition_rejected`, `claim.initiate_rejected`, `authz.claim_access_denied`, `authz.role_denied`, `cover.join_requested`, `mandate.cancel_requested`.

## 8. Existing state transitions (`src/security/claimStateMachine.ts`)
Draft→Submitted (CUSTOMER); Submitted→Verified, Verified→Screening, Screening→Review|Info Needed, Review→Decision|Info Needed (ASSESSOR, MANAGER); Info Needed→Screening (CUSTOMER), →Expired (SYSTEM); Decision→Paid (MANAGER), →Appeal (CUSTOMER); Appeal→Review (MANAGER); Withdrawn (CUSTOMER, no endpoint). `transitionClaim` is the only stage writer (verified: no `UPDATE claims SET stage` elsewhere).

## 9. Gaps required for Phase 3
| Gap | Needed by |
|---|---|
| Decision authority: ASSESSOR can decide today | §3 role restriction (DECISION REQUIRED in Phase 1; Phase 3 resolves it as MANAGER-only, see report) |
| No decision record (who/what/when/why/on-what) | §5, §7 |
| No authoritative payout amount | §8, §9 |
| No payout destination, no protection of it | §10 |
| No payout record / idempotency beyond the state machine | §11 |
| No decision/payout-specific audit actions | §12 |
| `transitionClaim` cannot carry extra statements in its batch | needed to write the decision/payout rows atomically with the stage change |

## 10. Anything that prevents safe implementation
- **Nothing blocking.** All required seams exist (`transitionClaim`, `auditStatement`, `loadAuthorizedClaim`, strict schemas, append-only triggers).
- Constraints to respect: no real money movement (payout is simulated); no evidence binding until Phase 2 lands (reserved column); the merged tree contains an **unmounted** MVC layer (`src/routes|controllers|services`) and an unmounted hard-coded SA-ID login stub — Phase 3 must not mount or build on them; `npm audit` on `0e75d6a` reports 2 high (`marked`, from the backend team's OpenAPI tooling) — not touched by Phase 3.
- Baseline on `0e75d6a` before any change: `npm test` 12 files, 183 passed, 1 todo; `npm run typecheck` exit 0.
