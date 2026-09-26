# Integration report

EasyClaim full-stack integration, hardening and repository cleanup, rebased onto `main` `abc3a3d` and pushed to `main`
on 26 Sep 2026. Final role model: CUSTOMER, ASSESSOR, MANAGER, INSURER_ADMIN, SUPERADMIN (team decision).

Status words used: **IMPLEMENTED · TESTED · PARTIALLY TESTED · LOCAL ONLY · PLANNED · KNOWN LIMITATION**.

## 0. Final state (read first)

- **Roles:** CUSTOMER (files claims) · ASSESSOR (verify, screen, review, request info) · MANAGER (+ decide, pay,
  re-open appeals) · INSURER_ADMIN (own insurer's staff accounts, tenant stats, read-only claims, no claim actions) ·
  SUPERADMIN (insurers, insurer-admin accounts, platform stats, read-only claims; not creatable via the API).
- **Accounts:** real `users` table (migration `0010_users.sql`, PBKDF2), `POST /auth/login`, `POST /auth/register`
  (customers only), `/admin/*`, `/tenant/*`. Demo accounts (local seed only, password `1234567`): `mike`, `lerato`,
  `sipho`, `assessor_discovery`, `manager_discovery`, `assessor_sanlam`, `manager_sanlam`, `admin_discovery`,
  `admin_sanlam`, `superadmin`.
- **Merge with main `abc3a3d`:** reverted the `decode()` login bypass, replaced the broken `admin.ts`, removed the
  magic-word login and the unsafe Ansa payout branch, rewrote the nightly expiry job through the state machine with
  audit, disabled the remote-only `[ai]` binding that broke local tests, deleted `*.orig`/`*.patch` and
  `add_cors.py`. Details: [SECURITY_INTEGRATION.md](SECURITY_INTEGRATION.md) §7.
- **Screens per role:** `docs/integration/evidence/app/f01`–`f09` (assessor sees "Manager decision required", manager
  sees "Record decision", insurer admin Team screen, superadmin portal).
- Sections 1–28 below describe the integration pass itself; where they mention an interim demo login or a
  three-role model, section 0 and the docs it links supersede them.

## 1. Executive summary

EasyClaim now runs as one application. The Flutter app signs in against the backend, creates and submits claims
with evidence, and the insurer portal verifies, screens, reviews, decides and pays them through the real API. The
backend is authoritative for identity, role, tenant, lifecycle, screening signals, decisions, decision integrity,
payout eligibility and audit.

Verified (all run on this PC, 26 Sep 2026):

| Check | Result |
|---|---|
| `backend`: `tsc --noEmit` | clean |
| `backend`: `vitest run` | 21 files, **354 passed** (was: 0 running on `main`) |
| `backend`: `npm audit` | 0 vulnerabilities |
| `frontend`: `flutter analyze` | No issues found (was 22 issues) |
| `frontend`: `flutter test` | **54 passed** (was 5 pass / 9 fail) |
| `frontend`: `flutter build web` | built |
| `quantum`: `pytest` | 27 passed (was 26 + 1 path failure) |
| Live API demo + attacks (`docs/integration/live-demo.sh`) | **72 passed, 0 failed** ([log](integration/evidence/LIVE_DEMO.log)) |
| Live app walkthrough (headless Chrome against `wrangler dev`) | customer, assessor, manager, customer-outcome and two attack flows completed; 30 screenshots in [integration/evidence/app/](integration/evidence/app/) |

The most important fix is a security regression: the restructure had added an unauthenticated login that issued
MANAGER tokens to anyone who typed "manager". It is replaced by a gated, audited demo login that is off in
production. One item needs a human: checking whether the deployed Worker ever ran that route (§17).

## 2. Repository before integration

Recorded in [INTEGRATION_PRECHECK.md](INTEGRATION_PRECHECK.md) and [INTEGRATION_ANALYSIS.md](INTEGRATION_ANALYSIS.md).
In short: the backend did not build (a source file left at the repo root), its tests had been moved into
`frontend/test`, the seed targeted a legacy schema, the app called eleven routes of which three matched, an open
token mint sat before authentication, and 114 MB of compiled Flutter output was tracked.

## 3. Canonical architecture

See [ARCHITECTURE.md](ARCHITECTURE.md). One place per responsibility:

| Responsibility | Location |
|---|---|
| Frontend | `frontend/` (`lib/core/api` client, `lib/core/auth` session, `lib/data/models` + `repositories`, screens) |
| Backend API | `backend/src` (`index.ts`, `endpoints/`, `security/`, `screening/`, `integrity/`) |
| Auth | `backend/src/security/actor.ts` (verify) + `backend/src/endpoints/demoAuth.ts` (local/demo issuer) |
| Lifecycle, decisions, PQC, payout, audit | `backend/src/security/*`, `backend/src/endpoints/claimsInsurer.ts` |
| Screening | `quantum/` (offline) → `backend/src/screening/` (read-only) |
| Database | `backend/migrations/0001..0008` |
| Tests | `backend/test`, `frontend/test`, `quantum/tests` |
| Docs | `docs/` |
| Not part of the app | `backend/legacy/`, `scripts/python_migration/` |

## 4. Frontend integration

IMPLEMENTED, TESTED (37 Flutter tests with a fake backend), and exercised live in Chrome.

- One `ApiClient` (`lib/core/api/api_client.dart`): base URL from `--dart-define=API_BASE_URL` (defaults to the
  emulator/localhost address), Bearer token on every call, 15 s timeout, multipart upload with explicit content type,
  typed `ApiException` with user-facing text per status/error code, sign-out on 401.
- `Session` (`lib/core/auth/session.dart`): in-memory token, actor, role, tenant, display name, expiry.
- Explicit `fromJson` models for every response used (`lib/data/models/api_models.dart`) and a single stage-mapping
  table (`lib/data/models/claim_stage.dart`).
- Repositories for auth, covers, claims and insurer actions; screens never touch HTTP.
- Every API-backed screen has loading, empty, error-with-retry states. No fallback fake data.
- Removed: hard-coded personal `workers.dev` URL, `x-user-id`, `pol_123`, `EC-<ms>` ids, register (no route), all
  skip-login bypasses, the 3.5 s stage auto-advance, fake verification, fabricated evidence, fake SLA charts,
  "auto-approval under 4 hours" text, client-side reading of a secret key.
- Platform: INTERNET permission in the main Android manifest; cleartext HTTP in the debug manifest only; iOS
  `NSAllowsLocalNetworking`.
- KNOWN LIMITATION: session is in memory (lost on reload); no secure storage yet. Not run on a physical device or
  emulator (no device on this PC); web build verified.

## 5. Backend integration

- Restored the build (`backend/src/integrity/routes.ts`), the test suite (`backend/test/`) and the
  migration-compatible seed.
- New route `GET /claims/:id` (claim detail for the owner or tenant staff; never returns `user_id`; masked payout
  destination). `GET /claims` now includes `claimed_amount_cents`; `GET /covers/my-covers` includes `insurer_name`.
- `GET /auth/me` echoes the verified actor.
- npm scripts fixed for the new layout; new `npm run demo:setup:local` builds the whole local demo database.
- Swagger/OpenAPI served only outside production; spec regenerated from the mounted routes.

## 6. Authentication

| Path | Status |
|---|---|
| Token verification (`requireActor`: HS256 pinned, iss/aud, exp/iat, per-role TTL, fail closed) | IMPLEMENTED, TESTED (unchanged since Phase 1) |
| Demo login `POST /auth/demo-login` | IMPLEMENTED, TESTED, **LOCAL ONLY**: off unless `ENVIRONMENT` ∈ {development, demo} and `DEMO_LOGIN_PASSWORD` ≥ 12 chars; fixed account table gives role and tenant; strict body; constant-time password compare; audited (`auth.demo_login`) |
| Offline token mint (`npm run token`) | IMPLEMENTED (unchanged) |
| Identity provider, key rotation, revocation | PLANNED (BACKEND-SEC-019) |

The client never supplies identity, role or tenant. Frontend role routing is UX only.

## 7. Authorization

IMPLEMENTED, TESTED. `requireRole` per route, per-edge roles in the state machine (decide/pay MANAGER only, ADMIN no
claim access), strict schemas on every body. New: `attackSuite.test.ts` ATTACK-06/07/09/12/13.

## 8. Tenant isolation

IMPLEMENTED, TESTED. `loadAuthorizedClaim` on every `:claimId` route including the new detail route. Cross-tenant and
other-customer access return 404 identical to a missing claim, audited. Live: the Sanlam assessor's queue shows only
`claim_sanlam_102` ([screenshot](integration/evidence/app/27_sanlam_queue.png)).

## 9. Claim lifecycle

Unchanged and authoritative: `Draft → Submitted → Verified → Screening → Review → Decision → Paid`, side states
`Info Needed`, `Appeal`; `Withdrawn`/`Expired` defined without route/job (KNOWN LIMITATION). The app renders the
backend stage through one mapping table. Seed restored to title-case stages with `tenant_id`.

## 10. Evidence

IMPLEMENTED, TESTED, live-verified: real file upload from the app (`file_picker`), PDF/JPEG/PNG ≤ 10 MiB, magic-byte
check (a renamed `.exe` → 415 in the live log), SHA-256 shown in the insurer detail, locked after submit (409).
KNOWN LIMITATION: the app lists evidence but does not download/preview it (route exists).

## 11. Screening

IMPLEMENTED, TESTED. `POST /screen` attaches and `GET /risk-signals` returns the advisory signal
(band NORMAL/ELEVATED/HIGH, recommendation, explanation, versions, digest); both audited. Customers get 403.
The insurer screening card shows classical and quantum signals, overall band, recommendation, the backend's
explanation and "Advisory signal. Human decision required." It never says "fraud detected"
([HIGH screenshot](integration/evidence/app/16_assessor_screening_HIGH.png)).

## 12. Quantum screening

Unchanged Phase 4 result, stated honestly: on synthetic data and a simulator the quantum-kernel one-class model did
**not** outperform the classical baseline (anomalies in each model's top 16: quantum 8, classical 9). The signal is
advisory; the pipeline is offline; no route writes signals. `quantum/` path fix only. 27 pytest pass.

## 13. ML-DSA / PQC

Unchanged Phase 5 implementation (ML-DSA-65, FIPS 204, `@noble/post-quantum`). Every decision is signed; verify
route; payout refuses a decision whose signature no longer verifies. The app shows "✓ Cryptographically verified ·
ML-DSA-65 · key id · verified at" for staff and "Decision verified" for customers, and the failure text when
verification fails. Private material never leaves the Worker. Wording avoids "immutable database".

## 14. Decision flow

Live-verified: Review → Decide (manager form: Approve/Reject, reason, optional amount) → signed decision → integrity
card VALID ([screenshot](integration/evidence/app/19b_manager_decision_scrolled.png)). Assessor sees "Manager
decision required." Client-supplied recommendation/band/score on decide → 400 (ATTACK-12).

## 15. Payout flow

Live-verified: Pay (simulated) at the recorded amount to the snapshot destination, idempotent replay, one payout per
claim; amount in the body → 400; pay before decision → 409; tampered decision → 409 `decision_integrity_failed`
(tests). Customer view shows "R4,200.00 paid to account ••••7890"
([screenshot](integration/evidence/app/24_customer_activity.png)).

## 16. Audit

IMPLEMENTED, TESTED. `endToEnd.test.ts` asserts the ordered `claim.stage_changed` trail Submitted…Paid plus
`claim.created`, `claim.screening_updated`, `claim.payout_details_set`, `evidence.uploaded`,
`screening.signal_attached`, `claim.decision_recorded`, `payout.completed_simulated`, and the new
`auth.demo_login` rows (never containing the password). No secrets or tokens are written to audit rows.

## 17. Security regression findings

| # | Finding | Severity |
|---|---|---|
| R1 | Open token mint at `POST /profile/login`: any caller who typed "manager" got a MANAGER token; any input got a `user123` token | CRITICAL (verified by test before the fix) |
| R2 | `main` did not build | HIGH |
| R3 | Backend tests not running | HIGH |
| R4 | Seed incompatible with the schema (no tenants, invalid stages) | MEDIUM |
| R5 | Swagger/OpenAPI public with a stale spec | LOW |
| R6 | App sent `x-user-id`, several calls without a token, hard-coded personal Worker URL, read a secret key client-side | MEDIUM |
| R7 | 114 MB of build output in git | LOW (hygiene) |
| **R8** | **Deployed Worker may have run R1** | **ACTION REQUIRED (human): check the deployed version; if affected, redeploy and rotate `JWT_SECRET`** |

## 18. Security fixes

R1 → `demoAuth.ts` (see §6) + 14 tests, old route now 401. R2/R3/R4 → files moved back, seed restored.
R5 → docs gated by `ENVIRONMENT`. R6 → one client, token everywhere, `--dart-define` base URL, secret read removed.
R7 → untracked and ignored (history not rewritten, see §26). `wrangler.toml` documents required secrets;
`npm run setup:local` generates all three local secrets without printing them. OWASP API Top 10 review:
[SECURITY_INTEGRATION.md](SECURITY_INTEGRATION.md).

## 19. Repository cleanup

Done (all reversible moves; nothing deleted from history):

| Action | Detail |
|---|---|
| Moved | `src/integrity/` → `backend/src/integrity/`; 20 backend test files `frontend/test/` → `backend/test/`; unmounted MVC layer, `schema.sql`, `drop_all.sql`, `test_static.ts` → `backend/legacy/` (with README, outside `tsconfig` include; grep-verified unreferenced); 12 root patch scripts → `scripts/python_migration/` |
| Untracked | `frontend/build/` (89 files, 119,953,153 bytes) + `.gitignore` rules for `frontend/build/`, `.dart_tool/`, `backend/.dev.vars`, `backend/.wrangler/`, `coverage/` |
| Removed | `frontend/lib/services/auth_service.dart` (superseded), `frontend/test/covers_and_wizard_test.dart` (tested only mock providers; replaced by 3 new test files), unused packages `fl_chart`, `timelines_plus`, `provider`, `flutter_svg` |
| Regenerated | `backend/src/openapi.json` from the mounted routes; Postman collection: new folder 00 (demo login) and 11 (detail, evidence, spoofing attacks) |

Proposed deletions, **not done** (need approval): `backend/legacy/` (whole folder), `scripts/python_migration/`,
`frontend/server.js` + `frontend/package.json` (Express proxy pointing at the wrong host, unused),
`frontend/lib/models/covers_models.dart`, `frontend/lib/models/claims_wizard_models.dart`,
`frontend/lib/models/README.md` (unreferenced), `.idea/`.

## 20. Database / migration fixes

Migrations 0001–0008 unchanged and coherent (applied by tests and by `demo:setup:local`; local D1 verified: 8
migrations, 5 claims, 5 signals, 0 claims without tenant). Seed: restored the schema-compatible version; the legacy
seed that referenced a `users` table is gone. No historical migration was edited. No new migration was needed.

## 21. API contract

[API_CONTRACT.md](API_CONTRACT.md): every route with auth, role, tenant rule, request, response, errors, state
requirement, audit event and frontend consumer; error-code table; stage mapping. Enforced by `endToEnd.test.ts`,
`attackSuite.test.ts` and the Flutter repository tests.

## 22. Tests

| Suite | Count | Notes |
|---|---|---|
| backend vitest | 300 in 20 files | +`demoAuth` (14), `endToEnd` (3, NORMAL and HIGH journeys + detail route), `attackSuite` (19 covering ATTACK-01..20) |
| Flutter | 37 | model parsing, stage mapping, ApiException mapping, session/role routing, repository request bodies (initiate body, no amount on Rejected, empty pay body), screening and integrity card wording, widget smoke tests |
| quantum pytest | 27 | unchanged behaviour |
| live script | 49 checks | real HTTP against `wrangler dev` |

## 23. End-to-end demo

Run live in the app (screenshots `00`–`27` in `docs/integration/evidence/app/`):
customer sign-in → covers → 7-step wizard (policy+category, eligibility, incident, payout details, evidence upload,
review, submitted) → assessor queue → verify → screen (NORMAL: "No screening signal for this claim" for the new
claim, HIGH card for `claim_demo_unusual`) → review → manager decide (Approve) → ML-DSA verified → pay → customer
sees Paid, decision, "Decision verified", payout. The HIGH-anomaly claim went through review and received a human
**Rejected** decision, signed and verified: HIGH did not auto-reject.

## 24. Attack demonstrations

Expected vs actual (tests `attackSuite.test.ts`; live log `integration/evidence/LIVE_DEMO.log`):

| ATTACK | Expected | Test | Live |
|---|---|---|---|
| 01 no token | 401 | ✓ | ✓ |
| 02 forged token / alg=none | 401 | ✓ | ✓ |
| 03 expired token | 401 | ✓ | – |
| 04 customer A ↔ B | 404 | ✓ | ✓ |
| 05 cross-tenant | 404 | ✓ | ✓ |
| 06 customer on assessor action | 403 | ✓ | ✓ |
| 07 assessor decide/pay | 403 | ✓ | ✓ |
| 08 X-User-Id | ignored / 404 | ✓ | ✓ |
| 09 role spoof | ignored / 400 | ✓ | ✓ |
| 10 tenant spoof | ignored / 400 | ✓ | ✓ |
| 11 fake quantum score | ignored / 400 | ✓ | ✓ |
| 12 fake recommendation | 400 | ✓ | ✓ |
| 13 fake amount | 422 / 400 | ✓ | ✓ |
| 14 illegal transition | 409 | ✓ | ✓ |
| 15 edit stored signal | DB refuses | ✓ | – |
| 16 modify signed decision | TAMPERED | ✓ | – (needs DB access) |
| 17 pay with invalid signature | 409 | ✓ | – |
| 18 replay payout | 200 replay / 409 new | ✓ | ✓ |
| 19 duplicate decision | 409 | ✓ | ✓ |
| 20 other tenant's evidence | 404 | ✓ | – |
| demo login as "manager" / with client role | 401 / 400 | ✓ | ✓ (also in the app UI) |

## 25. Remaining limitations

- Demo login is LOCAL ONLY with one shared password; no identity provider (PLANNED).
- Session not persisted in the app; no evidence download in the app; notifications derived from the claims list;
  `/profile`, `/client/*`, `/activities/*` remain stubs; support chat and consent screen are static content.
- Separation of duties (decider = payer), appeal limit, `Withdrawn`/`Expired`, per-environment wrangler config,
  ADMIN scope: DECISION REQUIRED (handoff 015–020).
- Append-only triggers can be dropped by a DB admin; ML-DSA then still detects decision edits, audit rows are unsigned.
- Rate limiter approximate; queue consumer not observed under `wrangler dev`.
- Not run on a physical device/emulator; web only.
- 114 MB build output remains in git history.
- The master plan `.docx` was not re-issued (note added in `docs/master-plan/README.md`).

## 26. Planned work

Identity provider + JWKS verification and secret rotation (019); secure session storage in the app; evidence
preview; per-environment `[env.production]` (018); decide the DECISION REQUIRED items; optional history rewrite to
drop the build output (every clone must be refreshed); delete the proposed legacy folders after team agreement.

## 27. Final architecture diagram

```
Flutter app (untrusted)  ──ApiClient──►  Auth (Bearer JWT; demo issuer LOCAL ONLY)
                                              │
                                        Hono Worker: rate limit → requireActor → requireRole → strict schema
                                              │            → loadAuthorizedClaim (owner / tenant)
                                              ▼
                                        Claim service (state machine, one D1 batch + audit row)
                                              │
                        Evidence (R2, SHA-256) │  Screening (advisory, offline) ─┬─ classical
                                              │                                  └─ quantum-kernel (simulator)
                                              ▼
                                        Human review → Decision (MANAGER) → ML-DSA-65 signature (key stays server-side)
                                              ▼
                                        Payout (simulated; verifies signature + destination) → audit_events → D1
```
Frontend is untrusted · quantum signal is advisory · ML-DSA private key is server-side · the database is not proof of
a decision without signature verification.

## 28. Hackathon demo notes

Follow [DEMO_RUNBOOK.md](DEMO_RUNBOOK.md). Reset the local database between rehearsals (stop the Worker, delete
`backend/.wrangler/state`, `npm run demo:setup:local`). Check port 8787 is free before `npm run dev`. Say "advisory
signal, a human decides", "detects that signed decision data changed", "simulated payout", "local demo login".

## Change summary (working tree vs `1e432f7`)

- 111 tracked files changed excluding the untracked build output: +5,523 / −9,125 lines; 89 build files untracked.
- Added: `backend/src/endpoints/demoAuth.ts` (renamed from `devLogin.ts`, rewritten), `backend/test/{demoAuth,endToEnd,attackSuite}.test.ts`, `backend/legacy/README.md`, `frontend/lib/core/**`, `frontend/lib/data/**`, `frontend/test/{models_test,api_and_repositories_test}.dart`, `frontend/test/support/`, `docs/{ARCHITECTURE,API_CONTRACT,DEMO_RUNBOOK,SECURITY_INTEGRATION,INTEGRATION_PRECHECK,INTEGRATION_ANALYSIS,INTEGRATION_REPORT}.md`, `docs/integration/live-demo.sh`, `docs/integration/evidence/**`.
- Moved: see §19. Deleted: `frontend/lib/services/auth_service.dart`, `frontend/test/covers_and_wizard_test.dart`.
- Dependencies: backend unchanged; Flutter + `file_picker`, `http_parser`; − `fl_chart`, `timelines_plus`, `provider`, `flutter_svg`.
- Migrations added: none. Secrets committed: none (`git ls-files` checked).
- Not committed, not pushed, history untouched.
