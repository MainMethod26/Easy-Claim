# EasyClaim: Frontend + Backend Integration Analysis (revision 3)

> **Historical.** This is the analysis of `main` at `1e432f7` *before* the integration pass. Everything in part A was
> fixed on 26 Sep 2026; see [INTEGRATION_REPORT.md](INTEGRATION_REPORT.md) for what was done and
> [ARCHITECTURE.md](ARCHITECTURE.md) / [API_CONTRACT.md](API_CONTRACT.md) for the current state.

Date: 2026-09-26. Branch `main` at `1e432f7` (pulled, up to date with `origin/main`).
Earlier revisions: rev 1 at `73aee43`, rev 2 at `9d53ed6`. This revision replaces both, because the repository was
restructured into `backend/` and `frontend/` and the app now makes real HTTP calls.

Written to be handed to an agent for brainstorming. Part A is the verdict, B what changed, C the backend, D the
frontend, E a call-by-call contract check, F the fix list, G the decisions a human must make.
Every claim was read from code on `main` or measured on this PC. "Verified" means I ran it.

---

## A. Verdict in ten lines

1. **The backend on `main` does not build.** `backend/src/index.ts:16` imports `./integrity/routes`, but that file was
   left behind at the repo root (`src/integrity/routes.ts`). `tsc` fails; `wrangler deploy` would fail the same way.
2. **The backend has no tests.** All 17 backend test files were moved into `frontend/test/`. `backend/test/` is empty.
   `vitest run` in `backend/` says "No test files found".
3. **The seed no longer matches the schema.** `backend/seed_sa_data.sql` was rewritten for the legacy `schema.sql`
   (`users` table, `provider`/`premium` columns, no `tenant_id`, UPPERCASE stages). Against the real migrations it fails
   with `no such table: users`. Without `tenant_id`, insurer staff see no claims at all.
4. **With those three put back, all 264 tests pass** (verified on a scratch copy). The security code itself moved over
   byte-for-byte unchanged.
5. **CRITICAL: the new dev login is an open token mint.** `POST /api/v1/profile/login` sits before `requireActor`,
   checks no password, and issues a MANAGER token to anyone who types "manager". Verified with a test. Any input gives
   at least a CUSTOMER token for `user123`. A MANAGER can decide and pay claims.
6. **The frontend now calls a deployed Worker** at a hard-coded `https://easy-claim-backend.pasekamabitsela22.workers.dev`.
   If that Worker runs this code, finding 5 is live on the internet. I did not probe it.
7. **Only 3 of 11 backend calls in the app match the API**: the two logins and the insurer claim list. Wrong paths,
   missing tokens, wrong field names and an invented `/dashboard` break everything else.
8. **The customer app cannot create a claim.** The wizard sends no token, sends fields the strict schema rejects, and
   skips the screening, payout and evidence steps that submit requires.
9. **The insurer portal cannot move a claim.** It has no verify/screen/review actions, posts to a non-existent
   `/decisions`, and its buttons key on `status` values that never occur.
10. **About 114 MB of compiled Flutter output is committed** under `frontend/build/` (one file is 69 MB). It is now in
    git history.

---

## B. What changed since revision 2 (`9d53ed6` → `1e432f7`)

Four commits, all by one backend-team member, 26 Sep 12:43–14:01:

| Commit | Subject |
|---|---|
| `bdbac70` | Merge remote-tracking branch and resolve index.ts conflicts |
| `558f0cd` | Move src/screening to backend/src/screening |
| `9bfde3a` | feat: Add Insurer admin portal and dev auth |
| `1e432f7` | Merge remote changes |

354 files changed. The main moves:

- **Backend moved to `backend/`**: `src/`, `migrations/`, `scripts/`, `wrangler.toml`, `package.json`, `tsconfig.json`,
  `vitest.config.mts`, Postman collection, `schema.sql` (+ new `drop_all.sql`, `test_static.ts`).
- **Flutter app moved to `frontend/`**: `lib/`, `pubspec.yaml`, `android/`, `ios/`, `assets/`, `test/`. New
  `frontend/web/` (web target), `frontend/server.js` + `package.json` (Express static server), `frontend/build/`.
- **Left behind or misplaced**:
  - `src/integrity/routes.ts` still at the root → backend build broken.
  - Backend `*.test.ts`, `helpers.ts`, `setup.ts`, `env.d.ts` in `frontend/test/` → backend has no tests.
  - `quantum/` still at the root, but the npm scripts `quantum:*`, `signals:import:local`, `demo:quantum:local` now
    run from `backend/` and point at `quantum/...` → broken paths.
  - Local `.dev.vars` is still at the root (gitignored, never moved). `wrangler dev` in `backend/` will not find it,
    so every request is 401 until one is created in `backend/`.
- **New backend code**: `backend/src/endpoints/devLogin.ts` mounted at `/api/v1/profile/login`; Swagger UI at
  `/swagger` and `/openapi.json` (both unauthenticated; new dep `@hono/swagger-ui`). Changes to the unmounted MVC layer
  (`dashboardRoutes/Service`, `identityService` register, `claimsService`).
- **New frontend code**: `AuthService` (in-memory token), real HTTP calls in 3 providers, admin/insurer portal
  (`main_admin.dart`, `admin_auth_screen`, `insurer_dashboard_screen`, `insurer_claim_details_screen`), "Thabo"
  renamed to "User", most bottom sheets turned into full-screen routes, All Covers tab replaced with a static insurer
  list, `CoversMockData` lookups removed from the wizard.
- **Root clutter**: 11 new one-shot patch scripts (`add_cors.py`, `fix_*.py`) and ~40 more moved into
  `scripts/python_migration/`. `add_cors.py` no longer matches its target and had no effect.
- **README not updated**: still says "Backend only… There is no frontend/UI" and documents root-level commands.
  29 docs still reference root `src/index.ts`.

---

## C. Backend (`backend/`)

### C.1 Build and test status (verified)

| Check | On `main` as committed | Scratch copy with 3 fixes* |
|---|---|---|
| `npm install` | ok | ok |
| `tsc --noEmit` | **fails**: `Cannot find module './integrity/routes'` | clean |
| `vitest run` | **"No test files found"** | 17 files, **264 passed** |
| same, with the new seed | – | all 17 files fail to load: `no such table: users` |

\* Fixes: copy `src/integrity/routes.ts` → `backend/src/integrity/`; copy `frontend/test/*.ts` → `backend/test/`;
restore the previous seed (`git show 9d53ed6:seed_sa_data.sql`).

No test covers `/profile/login`. The 264 passing tests prove the rest of the security model is intact, not that the
new route is safe.

### C.2 Security findings

**S1 CRITICAL: unauthenticated token mint** (`backend/src/endpoints/devLogin.ts`, mounted at `index.ts` before
`requireActor`). Verified with a probe test on the scratch copy (3/3 assertions passed):

```
POST /api/v1/profile/login {"email":"manager"}              -> 200, role MANAGER, tenant ins_discovery
  then GET /api/v1/claims with that token                   -> 200 (Discovery claim queue)
POST /api/v1/profile/login {"email":"x","password":"wrong"} -> 200, CUSTOMER user123; /covers/my-covers -> 200
POST /api/v1/profile/login (empty body)                     -> 200
```

- Role comes from a substring of user input: "assessor" → ASSESSOR, "manager" → MANAGER, anything else → CUSTOMER.
- Password is accepted and ignored. No environment gate, no rate limit beyond the global per-IP one, no audit row.
- A MANAGER token can `decide` and `pay` Discovery claims. Payouts are simulated, but the audit trail and the
  ML-DSA-signed decision records would show forged manager actions as legitimate.
- Every customer who logs in becomes the same person (`user123`), so there is no per-user separation in practice.
- The frontend advertises the trick: the admin login hint says "Admin ID (e.g., assessor_a1)".
- This undoes Phase 1's core claim ("tokens only from an issuer; fails closed"). The cyber docs and the pitch
  currently describe a system this route bypasses.

**S2 HIGH: build is broken on `main`.** Any deploy from `main` fails, so the deployed Worker is running some other
build. Nobody can tell which security controls are live.

**S3 HIGH: tests not running.** Every regression guard (BOLA, tenant isolation, state machine, payout, integrity) is
silently off.

**S4 MEDIUM: seed drops tenants.** Seeded claims have `tenant_id` NULL and UPPERCASE stages (`REVIEW`, `DECISION`).
Insurer staff get empty queues; the state machine rejects unknown stages. If the team built their local or remote D1
from `schema.sql` instead of the migrations, that database has no tenants, no audit triggers, no evidence, decisions,
payouts or signal tables, i.e. none of Phases 0–5.

**S5 LOW: Swagger and OpenAPI served unauthenticated** at `/swagger` and `/openapi.json`. Reveals the API map.
Acceptable for a hackathon if intended; the spec is the old Postman-derived one.

**S6 INFO: unmounted MVC layer** (`backend/src/controllers|routes|services`). An automated review flags
`x-user-id` header identity, default `user123`, unauthenticated decide/pay and ID-number-only login there. Verified
not imported by any live code, so not exploitable today. It is being actively edited (`/register`, `/dashboard`), and
the frontend calls those routes, which suggests someone intends to mount it. Mounting it would reopen every Phase 1
hole. Handoff item `BACKEND-SEC-021` covers this.

### C.3 Route inventory (unchanged from rev 2 except login and swagger)

All under `/api/v1`, all require `Authorization: Bearer <JWT>` except the login route. Strict JSON schemas: unknown
fields → 400. Money in integer cents. Stages title-case: `Draft, Submitted, Verified, Screening, Review, Decision,
Paid, Info Needed, Appeal, Withdrawn, Expired`. Errors: `{"error":"<code>"}`. Every response has `X-Request-Id`.

**New / unauthenticated**

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/profile/login` | `{idNumber?|email?}` anything | `{status:"success", token, profile:{id, first_name:<role>, last_name:<tenant or "User">, role, tenant_id}}` 1 h token |
| GET | `/swagger`, `/openapi.json` (no `/api/v1` prefix) | – | Swagger UI / spec |

**Customer**

| Method | Path | Body | Success |
|---|---|---|---|
| GET | `/covers/my-covers` | – | `{policies:[{id,user_id,plan_name,status,tenant_id}]}` |
| GET | `/covers/market-catalog` | – | `{catalog:[{id,provider,name,premium}]}` |
| POST | `/covers/join-request` | `{planId}` | `{status,message,planId,provider}` |
| GET | `/claims?limit=1..50` | – | `{claims:[{id,policy_id,tenant_id,stage,status,category,created_at,updated_at}]}` |
| POST | `/claims/verify-eligibility` | `{policyId}` | `{verified,context}` |
| POST | `/claims/initiate` | `{policyId, category?: Medical\|Vehicle\|Life\|Property\|Other}` | 201 `{status,claimId}` |
| PATCH | `/claims/:id/screening` | `{causeOfLoss, incidentDate: YYYY-MM-DD}` | `{status,message}` |
| PUT | `/claims/:id/payout-details` | `{claimedAmountCents, bankName, accountHolder, accountNumber}` | masked destination |
| POST | `/claims/:id/evidence` | multipart field `file`, PDF/JPEG/PNG ≤ 10 MiB | 201 `{evidenceId, sha256}` |
| GET | `/claims/:id/evidence`, `/evidence/:eid`, `/evidence/:eid/verify` | – | list / bytes / VALID\|TAMPERED |
| POST | `/claims/:id/submit` | – | Draft → Submitted; 422 `screening_incomplete` |
| GET | `/claims/:id/timeline`, `/decision`, `/payout`, `/decision/verify` | – | tracking views |
| POST | `/claims/:id/appeal` | `{reason}` | only from Decision + Rejected |

**Insurer** (ASSESSOR/MANAGER, own tenant, not Draft)

| Method | Path | Body | Edge / notes |
|---|---|---|---|
| POST | `/claims/:id/verify` | – | Submitted → Verified |
| POST | `/claims/:id/screen` | – | Verified → Screening; returns `riskSignals` |
| POST | `/claims/:id/review` | – | Screening → Review (Appeal → Review MANAGER only) |
| POST | `/claims/:id/request-info` | – | Screening/Review → Info Needed |
| POST | `/claims/:id/decide` | `{outcome: Approved\|Rejected, reason, approvedAmountCents?}` | MANAGER; Review → Decision; ML-DSA signed; needs `MLDSA_SEED` |
| POST | `/claims/:id/pay` | empty; optional `Idempotency-Key` | MANAGER; Decision(Approved) → Paid, simulated |
| GET | `/claims/:id/risk-signals` | – | advisory band + recommendation |

Stubs with fixed data: `/client/*`, `/profile`, `/profile/consent`, `/profile/mandates/*`, `/activities/*`,
`/ocr/process`. Not present: `/dashboard`, `/profile/register`, `GET /claims/:id`, `/decisions`, `/covers`,
`/covers/market`, any withdraw route.

### C.4 Config

- `backend/wrangler.toml`: unchanged content. D1 `easy-claim-db`, queue, R2 `easy-claim-evidence`, rate limiter
  100/60 s, `ALLOWED_ORIGINS = ""`, `JWT_ISSUER = easyclaim-dev`, `JWT_AUDIENCE = easyclaim-api`.
- Secrets: `JWT_SECRET`, `MLDSA_SEED` in `backend/.dev.vars` (missing on this PC) or `wrangler secret put`.
- Migrations `backend/migrations/0001..0008` unchanged.

---

## D. Frontend (`frontend/`)

### D.1 Shape

- Two entry points: `lib/main.dart` (customer app) and `lib/main_admin.dart` (insurer portal,
  `flutter run -t lib/main_admin.dart`). Customer login also routes ASSESSOR/MANAGER to the insurer dashboard.
- `pubspec.yaml` byte-identical to before. `http` is now used. No secure storage, no JSON models, no shared client.
- Targets: Android, iOS, and now **web** (`frontend/web/`, committed `build/web`, Express `server.js` on port 8081 that
  serves `build/web` and proxies `/api` to `https://easy-claim-frontend.pages.dev`, which is the frontend host, not
  the Worker; the proxy is unused because the app calls absolute URLs).
- Flutter SDK is not installed on this PC. Everything below is static reading; nothing was run.

### D.2 Auth

- `lib/services/auth_service.dart`: static in-memory `token`, `currentUserId`, `currentUserName`, `currentRole`,
  `currentTenant`; `authHeaders` adds `Content-Type` and `Authorization: Bearer`. Lost on restart.
- Login screens send `{idNumber, password}`; password is ignored by the backend.
- Register calls `/profile/register`, which does not exist (401 without token, 404 with).
- Demo bypasses ("Explore Live Demo as User", "Quick Demo Access") enter the app with no token at all.
- Logout: insurer sets token null then pops its only route (likely a blank screen); customer sign-out only shows a
  snackbar.
- No try/catch around login; raw `response.body` is shown in snackbars.

### D.3 Base URL

Hard-coded in every file: `https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/...`.
`ConfigService.apiBaseUrl` exists but is unused (default still `https://api.logo.dev`); `.env` is still not a Flutter
asset. There is no way to point the app at `wrangler dev` without editing every file.

### D.4 Mock vs real

| Screen | Data source today |
|---|---|
| Login / admin login | real (`/profile/login`) |
| Insurer dashboard | real (`/claims`) |
| Insurer claim details | real buttons, wrong endpoints (see E) |
| Covers → My Covers | calls `/covers` (404) → empty list; fields partly hard-coded |
| Covers → All Covers | static list of 5 insurers |
| Home | calls `/dashboard` (does not exist) → empty; falls back to hard-coded "Phone stolen R4,200" |
| Claim wizard | local and fake until the final submit, which fails |
| Claim Activity, Consent, Support, Notifications, Profile details | hard-coded |

### D.5 Platform and hygiene

- `frontend/android/app/src/main/AndroidManifest.xml` still has **no INTERNET permission** → release APKs cannot
  reach the backend (debug builds work).
- Web: backend `ALLOWED_ORIGINS = ""` → **every browser call is CORS-blocked**, including login, unless the deployed
  Worker overrides it. The wizard's `x-user-id` header also fails preflight.
- `frontend/build/`: 89 tracked files, ~114 MB, largest a 69 MB `.dill` kernel cache. Root `.gitignore` has `/build/`
  (root only), so it slipped in.
- Logo.dev publishable key hard-coded (client-safe by design); the app also reads `LOGO_DEV_SECRET_KEY` client-side,
  which should never ship in a client.
- Dart tests in `frontend/test/` still assert the old mock strings ("Thabo", 2 policies, campaigns) and will mostly
  fail. No tests for auth, providers' HTTP, or the insurer portal.

---

## E. Contract check: every app call vs the backend

| # | Where (frontend/lib/…) | App sends | Backend expects | Result today | Fix |
|---|---|---|---|---|---|
| 1 | `screens/auth_screen.dart:54` | POST `/profile/login {idNumber,password}` | same (any body) | 200 | works; but see S1 |
| 2 | `screens/auth_screen.dart:89` | POST `/profile/register` no token | no such route | 401 | add route or drop register |
| 3 | `screens/admin_auth_screen.dart:21` | POST `/profile/login` | same | 200 | works |
| 4 | `providers/covers_provider.dart:54` | GET `/covers` with token | `/covers/my-covers` | 404 | fix path; `provider` field does not exist, use `tenant_id` |
| 5 | `providers/covers_provider.dart:94` | GET `/covers/market` no token | `/covers/market-catalog` + token | 401 | fix path, send token |
| 6 | `providers/home_screen_provider.dart:49` | GET `/dashboard` | no such route | 404 | compose from `/claims` + `/timeline`, or add a route; stage parser expects UPPERCASE |
| 7 | `providers/claims_wizard_provider.dart:409` | POST `/claims/initiate` with `x-user-id`, no token, `{policyId, cause_of_loss, incident_date, location, police_case_number, description}` | token; `{policyId, category?}` only | 401 (then 400 strict) | token; send only `policyId`+`category`; move narrative to PATCH screening |
| 8 | `providers/claims_wizard_provider.dart:430` | POST `/claims/:id/submit`, no token | token; screening done first | 401 (then 422) | add PATCH screening, PUT payout-details, POST evidence before submit |
| 9 | `screens/insurer_dashboard_screen.dart:26` | GET `/claims` | same | 200 | reads `amount_cents` (absent) and shows `status` instead of `stage` |
| 10 | `screens/insurer_claim_details_screen.dart:20` | POST `/claims/:id/decisions {status, approved_amount_cents, reason}` | `/decide {outcome, reason, approvedAmountCents?}` | 404 (then 400) | fix path and names; no amount on Rejected; MANAGER only |
| 11 | `screens/insurer_claim_details_screen.dart:48` | POST `/claims/:id/pay` empty | same | works if reachable | – |

Also: the insurer Approve/Reject buttons show only when `status` is `Submitted` or `Under_Review`. The backend's
`status` is `Pending` until a decision, so the buttons never render. They should key on `stage == "Review"`.
The portal has no verify/screen/review actions, so no claim can ever reach Review from the app.

Never called by the app: `my-covers`, customer `/claims`, `screening`, `payout-details`, `evidence`, `timeline`,
`decision`, `payout`, `appeal`, `verify`, `screen`, `review`, `request-info`, `risk-signals`, `decision/verify`.

---

## F. Fix list, in order

### F.1 Repo repair (backend team, ~1 hour, mechanical)

1. `git mv src/integrity backend/src/integrity`.
2. `git mv frontend/test/*.ts backend/test/` (17 tests + `helpers.ts`, `setup.ts`, `env.d.ts`).
3. Restore the migration-compatible seed: `git show 9d53ed6:seed_sa_data.sql > backend/seed_sa_data.sql`. If the new
   columns are wanted, add a migration `0009` instead of editing the seed.
4. Fix `quantum:*`, `signals:import:local`, `demo:quantum:local` paths (`../quantum/...`) or move `quantum/` too.
5. `git rm -r --cached frontend/build` and add `frontend/build/` (or `**/build/`) to `.gitignore`.
6. Move root `fix_*.py` / `add_cors.py` into `scripts/python_migration/` or delete them.
7. Update README "Running Locally" to `cd backend`, and add a frontend section.
8. Verify: `cd backend && npm test && npm run typecheck` → expect 264 passing.

### F.2 Close S1 without losing the demo login

Pick one (decision G1). The minimum that keeps the demo working:

- Mount `devLogin` only when `ENVIRONMENT === "development"` (a var set in `.dev.vars`, absent in deployed config),
  so the route 404s in any deployed Worker.
- Map login ids exactly, not by substring: a fixed table of demo accounts (`user123`, `user456`, `assessor_a1`,
  `manager_a1`, `assessor_b1`, `manager_b1`) and 401 for anything else. Optionally a shared demo PIN from a secret.
- Validate the body with a strict schema, audit every login (`auth.dev_login`), and add a test that the route is
  absent without the flag.
- Record it in `docs/security/BACKEND_SECURITY_HANDOFF.md` as a dev-only stub so the security story stays honest.

### F.3 Make the app talk to the API correctly (frontend team)

1. One `ApiClient` with a base URL from `--dart-define=API_BASE_URL` (default `http://10.0.2.2:8787/api/v1` for the
   emulator), always sending `AuthService.authHeaders`. Remove `x-user-id`. Map `{error}` + `X-Request-Id` to a typed
   exception.
2. Fix paths: `/covers` → `/covers/my-covers`, `/covers/market` → `/covers/market-catalog`, `/decisions` → `/decide`.
3. Home: replace `/dashboard` with `/claims` + `/claims/:id/timeline`; parse title-case stages; remove the old
   auto-advance.
4. Wizard as the backend expects: initiate `{policyId, category}` → PATCH screening `{causeOfLoss (fold location,
   SAPS no., description into it), incidentDate YYYY-MM-DD}` → PUT payout-details (new bank-details step) → POST
   evidence multipart (add `image_picker`/`file_picker`) → submit → show `/timeline`.
5. Insurer portal: drive buttons from `stage`; add Verify / Screen / Review / Request info; Approve/Reject only for
   MANAGER at `Review`, body `{outcome, reason, approvedAmountCents}` with no amount on Rejected; show the risk signal
   from `/screen` or `/risk-signals`; show `decision/verify` as a "signed" badge.
6. Keep the token across restarts (`flutter_secure_storage`); proper logout; try/catch around every call.
7. Platform: INTERNET permission in the main manifest; set `ALLOWED_ORIGINS` to the web origin if web is demoed.
8. Update Dart tests to inject a fake client.

### F.4 Local run once F.1 is done

```bash
cd backend
npm install
npm run setup:local            # creates backend/.dev.vars with JWT_SECRET and MLDSA_SEED
npm run db:migrate:local       # 0001..0008
npm run db:seed:local
npm run dev                    # http://127.0.0.1:8787 (slow to start on this PC; poll until it answers 401)
npm run token -- --demo        # offline tokens, no login route needed

cd ../frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787/api/v1          # customer app
flutter run -t lib/main_admin.dart --dart-define=API_BASE_URL=...          # insurer portal
```

---

## G. Decisions to brainstorm

- **G1 Login.** (a) dev-only login gated by env + exact demo account table (recommended); (b) paste tokens from
  `npm run token`; (c) real identity provider (out of hackathon scope). Whatever is chosen, the deployed Worker must
  not mint MANAGER tokens for anyone.
- **G2 Is the deployed Worker running the open login?** Someone with Cloudflare access should check the deployed
  version and rotate `JWT_SECRET` if the route was live, since every token ever minted by it stays valid for 1 hour.
- **G3 Which database is the team really using?** Migrations (`0001..0008`, all security tables) or `schema.sql`
  (none of them). The demo and the security claims only hold on the migrations.
- **G4 `/dashboard` and `/register`.** Add real, guarded routes to `endpoints/` with tests, or compose from existing
  routes in the app. Do not mount the MVC layer to get them.
- **G5 One user per login.** Today every customer is `user123`. For the demo, is one customer enough, or should the
  table map several demo customers?
- **G6 Web or mobile for the demo?** Web needs `ALLOWED_ORIGINS` and a deployed Worker; mobile needs the INTERNET
  permission for release builds.
- **G7 Wizard fields.** Fold location / SAPS number / description into `causeOfLoss`, or extend the strict screening
  schema (backend change + tests).
- **G8 Category vocabulary.** App `device_electronics / vehicle_transit / home_property / personal_health` vs backend
  `Medical / Vehicle / Life / Property / Other`: map in the app, or change the backend enum.
- **G9 Insurer UX scope.** Full stage-by-stage portal, or a single "advance" button that calls the next legal edge.
- **G10 Show the security proofs?** Evidence SHA-256, ML-DSA "signed decision" and risk-signal badges would make the
  cyber and quantum work visible to judges.
- **G11 Clean up.** Delete `backend/src/{controllers,routes,services}`, `schema.sql`, `drop_all.sql`,
  `test_static.ts`, root scripts, `frontend/server.js` proxy?
- **G12 History bloat.** Leave the 114 MB build in history, or rewrite history before the final submission (needs
  every teammate to re-clone).

---

## H. Evidence

- Backend build: `cd backend && npx tsc --noEmit` → `src/index.ts(16,50): error TS2307: Cannot find module './integrity/routes'`.
- Backend tests: `cd backend && npx vitest run` → `No test files found, exiting with code 1`.
- New seed: `Error: D1_ERROR: no such table: users: SQLITE_ERROR`.
- Scratch copy with fixes: `Test Files 17 passed (17), Tests 264 passed (264)`, `tsc` exit 0.
- Login probe (scratch copy only, never against the deployed Worker): 3 tests passed as listed in C.2.
- Security files diff `9d53ed6` → `1e432f7`: all `src/security/*`, `endpoints/*` (except new `devLogin.ts`),
  `screening/*` are 100% renames.
- Committed build: `git ls-files frontend/build` → 89 files, 119,953,153 bytes.
