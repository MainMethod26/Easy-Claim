# Parallel work rules (Phases 2, 3, 4)

Written 2026-09-26 when Phase 1 was closed on `main`. Three phases now run at the same time on
different machines and in different Claude sessions. These rules keep the security work mergeable.

## Branches

| Phase | Branch | Who | Worktree (this PC) |
|---|---|---|---|
| 2 Evidence + OCR | `phase-2` | teammate, pushes to origin | none |
| 3 Decision + payout | `phase-3` | Claude session A | `../ec-phase3` |
| 4 Quantum screening signal | `phase-4` | Claude session B | `../ec-phase4` |

- Branch from `main`, never from `cyber`. `cyber` is fully merged and frozen; do not commit to it.
- Rebase onto `main` before opening a PR. Merge order at the end: 2, then 3, then 4.
- One phase per worktree. Never run two sessions in the same checkout.
- Do not use bare `git stash` in a worktree; the stash stack is shared.

## Reserved migration numbers

| Migration | Owner |
|---|---|
| `0004_*.sql` | Phase 2 (evidence storage, hashes) |
| `0005_*.sql` | Phase 3 (decision records, rules version, payout approvals) |
| `0006_*.sql` | Phase 4 (screening signals) |

Never renumber another phase's migration. Existing 0001 to 0003 are frozen.

## File ownership

| Files | Owner | Others may |
|---|---|---|
| `src/security/*` | shared, Phase 1 baseline | add functions; never weaken a check. Any change needs a test |
| `src/endpoints/claimsInsurer.ts` | Phase 3 (decide, pay) | Phase 4 adds at most a read call inside the `/screen` handler |
| `src/endpoints/ocr.ts`, evidence routes, queue consumer | Phase 2 | not touch |
| `src/screening/*` (new) | Phase 4 | not touch |
| `quantum/*` (new, Python) | Phase 4 | not touch |
| `src/index.ts` | shared | append route mounts only; keep `requireActor` on `/api/v1/*` |
| `src/controllers`, `src/routes`, `src/services` | backend team | not mount; not touch |
| `lib/` (Flutter) | backend team | not touch |
| `docs/security/*`, `README.md` | shared | edit your own rows; expect a small merge |
| `docs/phase-reports/PHASE_0N_*` | phase N | not touch other phases' reports |

## Local dev

- Each session runs `wrangler dev` on its own port: Phase 3 uses `--port 8788`, Phase 4 uses `--port 8789`.
- Each worktree has its own `.wrangler/` state and needs its own `npm install` and `npm run setup:local`.

## Every phase still follows the master plan

Inspect first, smallest change, tests with every security-sensitive change, typecheck + `npm test` + `npm audit`
green, `PHASE_0N_REPORT.md` with actual results, no commit or push without approval.
