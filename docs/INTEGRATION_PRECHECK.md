# Integration precheck

Written before any code change in the integration pass. Branch `main` at `1e432f7`, working tree clean apart from
`docs/INTEGRATION_ANALYSIS.md` (the analysis this precheck builds on). Date 2026-09-26.

Status words: **DONE · PARTIAL · BROKEN · DUPLICATE · STALE · UNREACHABLE · MISSING · PLANNED**.

## Commands run before coding

| Command | Result |
|---|---|
| `git status`, `git log --oneline -20` | clean; last 4 commits restructure into `backend/` + `frontend/` (`bdbac70`, `558f0cd`, `9bfde3a`, `1e432f7`) |
| `cd backend && npx tsc --noEmit` | **BROKEN**: `src/index.ts(16,50): Cannot find module './integrity/routes'` |
| `cd backend && npx vitest run` | **BROKEN**: `No test files found` |
| same on a scratch copy with the integrity routes, tests and previous seed restored | 17 files, 264 passed, `tsc` clean |
| `cd backend && npm audit` | 0 vulnerabilities |
| `pytest quantum/tests` (Phase 4 venv) | 26 passed, **1 failed**: `test_seed_claims_parse_with_real_schema` reads `<root>/seed_sa_data.sql`, which moved |
| `flutter analyze`, `flutter test` | **not run**: no Flutter SDK on this PC (being installed for this pass) |

## 1. Current repository structure

```
Easy-Claim-main/
  backend/        Worker (Hono) — package.json, wrangler.toml, src/, migrations/, scripts/, seed, schema.sql (legacy)
    test/         EMPTY
  frontend/       Flutter app — lib/, pubspec.yaml, android/, ios/, web/, test/, build/ (committed), server.js
    test/         2 Dart tests + 17 backend *.test.ts + helpers.ts, setup.ts, env.d.ts (misplaced)
  src/integrity/  routes.ts only (left behind)
  quantum/        Python Phase 4 pipeline + tests + results/*.sql
  docs/           security, quantum, phase reports, master plan
  scripts/python_migration/   ~45 one-shot codegen/patch scripts
  fix_*.py, add_cors.py, convert.js   root patch scripts (11 + 1)
  .idea/          IDE config, tracked
```

## 2. Canonical frontend location — DONE
`frontend/` (Flutter). No other frontend exists. Two entry points: `lib/main.dart`, `lib/main_admin.dart`.

## 3. Canonical backend location — BROKEN
`backend/` is canonical (it has `wrangler.toml`, `package.json`, all security code). Broken because
`backend/src/integrity/routes.ts` is missing (it sits in root `src/integrity/`).

## 4. Canonical database / migrations — DONE (seed BROKEN)
`backend/migrations/0001..0008`, unchanged by the restructure. No other migrations directory. The seed is broken (§25).

## 5. Canonical quantum implementation — PARTIAL
`quantum/` at the repo root (Python, offline). Only one copy. Its test and `experiment.py` still read
`<root>/seed_sa_data.sql`; the backend npm scripts that import its results now run from `backend/` with wrong
relative paths.

## 6. Canonical ML-DSA implementation — BROKEN (code DONE)
`backend/src/security/integrity.ts` (unchanged, `@noble/post-quantum`). Its routes file is the missing one (§3).

## 7. Authentication — BROKEN (security regression)
- `backend/src/security/actor.ts` `requireActor`: HS256 JWT, pinned alg, iss/aud, TTL caps, role/tenant rules. DONE, unchanged.
- `backend/src/endpoints/devLogin.ts` at `POST /api/v1/profile/login`, mounted **before** `requireActor`: no password,
  no environment gate, role chosen by substring ("manager" → MANAGER of `ins_discovery`). Verified on a scratch copy.
  **BROKEN / critical.**
- `backend/src/controllers/identityController.ts` login by SA ID number only: UNREACHABLE (not mounted).
- Offline `scripts/mint-token.mjs`: DONE.

## 8. Authorization — DONE
`rbac.ts` (role gate), `claimAccess.ts` (`loadAuthorizedClaim`: owner / tenant / drafts private → 404),
state machine per-edge roles. Unchanged, 100% renames.

## 9. Claim lifecycle — DONE (backend), BROKEN (frontend, seed)
Backend `claimStateMachine.ts`: title-case stages. New seed uses `REVIEW`/`DECISION`/`SUBMITTED` (invalid).
Frontend parses UPPERCASE stages and keys insurer buttons on `status`.

## 10. Screening — DONE (backend), MISSING (frontend)
`backend/src/screening/*` with band, recommendation, versions, digest, audit. Frontend shows no signal anywhere.

## 11. Decision — DONE (backend), BROKEN (frontend)
`POST /decide` MANAGER, signed. Frontend posts `/decisions` with snake_case fields → 404.

## 12. Payout — DONE (backend), PARTIAL (frontend)
`POST /pay` verifies signature and destination. Frontend call path is right, but no claim can reach it through the app.

## 13. Audit — DONE
`audit_events` append-only, used by every transition and refusal. Exception: the dev login writes no audit row.

## 14. Frontend API integration — BROKEN
3 of 11 backend calls match. Hard-coded `https://easy-claim-backend.pasekamabitsela22.workers.dev` in every file,
no shared client, `x-user-id: user123` header on claim calls, several calls without a token.
Full table: `docs/INTEGRATION_ANALYSIS.md` §E.

## 15. Frontend authentication — PARTIAL
In-memory `AuthService` token. Register hits a non-existent route. Demo bypass buttons enter the app with no token.
Logout does not clear state.

## 16. Frontend claim lifecycle — BROKEN
Wizard calls only `initiate` (wrong body, no token) and `submit`; skips screening, payout details, evidence.

## 17. Frontend screening — MISSING
## 18. Frontend decision — BROKEN (wrong route, wrong fields, never rendered)
## 19. Frontend payout — PARTIAL (right call, unreachable)

## 20. Test locations — BROKEN
Backend tests in `frontend/test/`, `backend/test/` empty. Dart tests in `frontend/test/` assert old mock strings
(STALE). Quantum tests in `quantum/tests` (1 path failure).

## 21. Duplicate / stale code
| Item | Status | Evidence |
|---|---|---|
| `backend/src/controllers`, `routes`, `services`, `types/env.ts` | UNREACHABLE | not imported by `index.ts` or any live module (grep); use `x-user-id` + default `user123`, unauthenticated decide/pay |
| `backend/schema.sql`, `backend/drop_all.sql` | STALE | legacy schema, not a migration; drop_all targets legacy tables |
| `backend/test_static.ts` | STALE | not in any script or tsconfig include |
| `backend/src/openapi.json` | STALE | Postman-derived, lists routes that do not exist |
| root `fix_*.py`, `add_cors.py`, `convert.js`, `scripts/python_migration/*` | STALE | one-shot patchers; `add_cors.py` no longer matches its target |
| `frontend/server.js`, `frontend/package.json` | STALE | proxies `/api` to the Pages frontend host, not the Worker; app never uses relative `/api` |
| `frontend/lib/services/config_service.dart` `apiBaseUrl` | STALE | default `https://api.logo.dev`, unused |
| `frontend/lib/models/covers_models.dart` `CoversMockData` | STALE (test fixture) | only tests use it |
| root `src/integrity/routes.ts` | DUPLICATE location | belongs in `backend/src/integrity/` |

## 22. Generated artifacts — BROKEN
`frontend/build/`: 89 tracked files, 119,953,153 bytes (largest a 69 MB `.dill`). Root `.gitignore` rule `/build/`
only covers the root. Already in history. `.idea/` tracked (minor).

## 23. Security regressions
| # | Finding | Status |
|---|---|---|
| R1 | Open token mint `POST /api/v1/profile/login` | BROKEN, critical |
| R2 | `main` does not build → nobody knows what the deployed Worker runs | BROKEN |
| R3 | Backend tests not running | BROKEN |
| R4 | Seed drops `tenant_id`, invalid stages | BROKEN |
| R5 | `/swagger`, `/openapi.json` unauthenticated, serve a stale spec | PARTIAL (low) |
| R6 | Frontend sends `x-user-id` | PARTIAL (ignored by live backend, would matter if the MVC layer were mounted) |
| R7 | Frontend reads `LOGO_DEV_SECRET_KEY` client-side | PARTIAL (empty today) |
| R8 | Deployed Worker may expose R1 | UNKNOWN — needs someone with Cloudflare access |

No secrets tracked: `git ls-files` shows no `.dev.vars`, `.env`, Postman environment or key material.

## 24. Broken / mismatched configuration
- `backend/package.json` quantum scripts point at `quantum/...` relative to `backend/` → BROKEN.
- Local `.dev.vars` is at the repo root (stale); `backend/.dev.vars` MISSING → `wrangler dev` answers 401 to everything.
- `MLDSA_SEED` required but not declared in `wrangler.toml` → easy to miss.
- `ALLOWED_ORIGINS = ""`; the app now has a web target → browser calls CORS-blocked.
- Main AndroidManifest has no INTERNET permission → release builds offline.
- `.env` not a Flutter asset; `ConfigService` fails silently.
- README describes the old root layout and says there is no frontend.

## 25. Migration / seed problems
- Migrations 0001–0008 coherent (applied in order by the test harness; 264 tests pass on them).
- `backend/seed_sa_data.sql` (new) inserts into `users` (no such table), uses `provider`, `insurance_type`, `premium`
  (no such columns), omits `tenant_id`, uses `REVIEW`/`DECISION`/`SUBMITTED`. BROKEN.
- The previous seed (`git show 9d53ed6:seed_sa_data.sql`) matches the schema and the tests. Quantum demo claims
  (`quantum/results/demo_claims.sql`) add a NORMAL and a HIGH_ANOMALY claim for `user123` at `ins_discovery`.

## 26. Local demo blockers
Backend build (§3), missing `backend/.dev.vars` incl. `MLDSA_SEED`, broken seed, broken quantum import paths,
no safe login for the app, frontend base URL hard-coded to a deployed Worker, frontend calls mismatched, no Flutter SDK.

## 27. Proposed canonical architecture
```
frontend/ (Flutter)  ── one ApiClient (base URL via --dart-define) ──►  backend/ (Hono Worker)
  core/api, core/auth, data/models, data/repositories, screens                ├─ auth: requireActor (JWT)
                                                                              │    + dev/demo login, env-gated
quantum/ (offline Python) ── results/*.sql ──► D1 screening_signals          ├─ endpoints/* (only mounted API)
backend/migrations (only schema source) · backend/seed_sa_data.sql (demo)    ├─ security/* (authz, lifecycle, integrity)
backend/test (vitest) · frontend/test (Dart) · quantum/tests (pytest)         └─ D1 + R2 + queue
docs/ (all documentation)
```

## 28. Proposed cleanup list
Non-destructive now (moves, untracking, ignore rules):
1. `src/integrity/` → `backend/src/integrity/`.
2. `frontend/test/*.ts` → `backend/test/`.
3. Restore the migration-compatible seed.
4. Untrack `frontend/build/` (files stay on disk) and ignore it.
5. Move root patch scripts into `scripts/python_migration/`.
6. Move the unmounted MVC layer, `schema.sql`, `drop_all.sql`, `test_static.ts` into `backend/legacy/` (outside `src/`,
   so it cannot be mounted or type-checked by accident), with a README.

Deletion proposals (need approval, not done in this pass): `backend/legacy/`, `scripts/python_migration/`,
`frontend/server.js` + `frontend/package.json`, root `.dev.vars` (local, untracked), `.idea/`.

## 29. Risks requiring human approval
- Rotating `JWT_SECRET` on the deployed Worker if the open login was ever deployed (R8).
- Rewriting git history to remove the 114 MB build (every teammate re-clones).
- Deleting legacy code and scripts (§28).
- Whether a deployed demo should enable the demo login at all (it is off by default after this pass).
- Commit and push of this pass.
