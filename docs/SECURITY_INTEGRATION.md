# Security of the integrated system

What changed for security in the integration pass (26 Sep 2026), and an OWASP API Security Top 10 (2023) review of
the integrated app. The Top 10 is used as a review framework; this is **not** a compliance claim.
Phase-level detail stays in [security/README.md](security/README.md) and the phase reports.

Status words: IMPLEMENTED · TESTED · LOCAL ONLY · PARTIAL · PLANNED · KNOWN LIMITATION.

## 1. Regressions found and fixed

| # | Regression (introduced by the `backend/` + `frontend/` restructure, commits `bdbac70`..`1e432f7`) | Fix | Evidence |
|---|---|---|---|
| R1 | `POST /api/v1/profile/login` mounted before `requireActor`: no password, role chosen by substring ("manager" → MANAGER of `ins_discovery`), no audit | Replaced by real accounts: `POST /api/v1/auth/login` over the `users` table (`backend/src/endpoints/auth.ts`, PBKDF2 hashes, role and tenant from the row, strict body, uniform 401, audited without the password). An interim gated demo login existed for a few hours and was removed with the three-role change. Old path now 401 | `backend/test/accounts.test.ts`, live log |
| R2 | `main` did not build (`src/integrity/routes.ts` left at the repo root) | moved to `backend/src/integrity/` | `tsc` clean |
| R3 | Backend tests had moved into `frontend/test`; `backend/test` empty → no tests ran | moved back | 20 files, 300 tests |
| R4 | Seed rewritten for the legacy schema (`users` table, no `tenant_id`, `REVIEW`-style stages) | migration-compatible seed restored; the legacy schema moved to `backend/legacy/` | `migration.test.ts`, local D1 check |
| R5 | `/swagger` + `/openapi.json` public, serving a stale spec | served only when `ENVIRONMENT` is development/demo; spec regenerated from the mounted routes | `demoAuth.test.ts` |
| R6 | Flutter app sent `x-user-id: user123`, called several routes without a token, hard-coded a personal `workers.dev` URL | one API client, token on every call, base URL via `--dart-define` | `frontend/test` |
| R7 | 114 MB of compiled Flutter output tracked in git | untracked + ignored (still in history) | `git ls-files frontend/build` = 0 |

**Open, needs a human (not fixable from this repo):** if the Worker at
`easy-claim-backend.pasekamabitsela22.workers.dev` was deployed from `1e432f7`-era code, R1 was live on the internet.
Someone with Cloudflare access should check the deployed version and rotate `JWT_SECRET` (`wrangler secret put
JWT_SECRET`), which invalidates every token it minted. Tokens were 1-hour, so exposure after rotation is nil.

## 2. Authentication boundary and the three-role model

```
production (PLANNED)          identity provider ──► JWT (asymmetric, JWKS) ─┐
now (IMPLEMENTED)             POST /auth/login ── users table (PBKDF2) ──►  HS256 JWT ─┼─► requireActor ─► actor {id, role, tenantId}
tests / Postman (LOCAL ONLY)  npm run token (offline mint) ─► HS256 JWT ─────────────┘
```

Roles (final, 26 Sep 2026):

| Role | Tenant | Can | Cannot |
|---|---|---|---|
| `CUSTOMER` | – | register, file and track own claims, appeal | see anyone else's data, screening signals |
| `ASSESSOR` | required | verify, screen, review, request information on its insurer's claims; see screening signals | decide, pay, re-open appeals |
| `MANAGER` | required | everything an assessor does + decide, pay (simulated), re-open appeals | act on another insurer's claims |
| `INSURER_ADMIN` | required | manage its insurer's staff (create assessors, managers, admins; enable/disable), tenant stats, read its insurer's claims | move a claim, see screening signals |
| `SUPERADMIN` | – | create insurers and insurer admins, platform stats, read all insurers' claims | move a claim, see screening signals; cannot be created through the API |

- `requireActor` (`backend/src/security/actor.ts`) is still the only place identity is established. Role and tenant
  are read from the token, which `/auth/login` signs from the `users` row; the client never supplies them.
- Registration creates customers only. Insurer admins are created by a superadmin; assessors, managers and further
  insurer admins by their tenant's admin, with the tenant taken from the token (a `tenantId` in the body is a 400).
  Superadmins cannot be created or disabled through the API (bootstrap script only).
- Login answers the same 401 body after the same PBKDF2 work for unknown users, wrong passwords and disabled accounts
  (no username enumeration by response or timing). Every attempt is audited without the password.
- KNOWN LIMITATIONS: no token revocation (a disabled account keeps its token ≤ 1 h), no password reset or MFA, one
  shared HS256 secret; password minimum is 6 characters (hackathon setting, `MIN_PASSWORD_LENGTH`); demo accounts share
  the agreed password `1234567` and are seeded locally only (`npm run db:seed:users:local`), never remotely except a
  single superadmin with a strong password.
- **Separation of duties.** Only a MANAGER decides and pays; assessors prepare claims; insurer admins and
  superadmins administer accounts but can never move a claim, so nobody who creates accounts can also approve money.

## 3. OWASP API Security Top 10 (2023) review

| Risk | What EasyClaim does | Status | Proof |
|---|---|---|---|
| API1 Broken Object Level Authorization | `loadAuthorizedClaim` on every `:claimId` route (claims, evidence, decision, verify, payout, risk signals): owner or same-tenant staff; Drafts private; denial = 404 identical to missing; audited | IMPLEMENTED, TESTED | `bola.test.ts`, `tenant.test.ts`, `attackSuite` 04/05/08/10/20, live log |
| API2 Broken Authentication | HS256 pinned, iss/aud, exp+iat, per-role TTL, fail closed; open login removed; real accounts with PBKDF2 hashes, uniform 401, audited | IMPLEMENTED, TESTED; IdP/rotation/revocation PLANNED | `auth.test.ts`, `accounts.test.ts`, `attackSuite` 01–03 |
| API3 Broken Object Property Level Authorization | strict schemas reject `stage`, `status`, `role`, `tenantId`, scores, amounts; responses never return `user_id` to staff, account numbers (hash + last 4 only), signal feature values to customers | IMPLEMENTED, TESTED | `massAssignment.test.ts`, `attackSuite` 09–13, `endToEnd.test.ts` |
| API4 Unrestricted Resource Consumption | per-IP and per-actor rate limit (100/60 s), 64 KB JSON / 10 MiB upload caps, `limit` ≤ 50 | IMPLEMENTED (approximate limiter) | `hardening.test.ts` |
| API5 Broken Function Level Authorization | `requireRole` per route + per-edge roles in the state machine (claim work ASSESSOR/MANAGER; decide/pay/appeal re-review MANAGER only; customers, insurer admins and superadmins never reach them; `/admin/*` SUPERADMIN only; `/tenant/*` INSURER_ADMIN only) | IMPLEMENTED, TESTED | `rbac.test.ts`, `accounts.test.ts`, `attackSuite` 06/07/21/22/24 |
| API6 Unrestricted Access to Sensitive Business Flows | payout: MANAGER, approved + signed decision, destination snapshot match, one per claim, idempotency; decision: MANAGER, Review only, approved ≤ claimed; account administrators cannot move claims; the same manager may still decide and pay (BACKEND-SEC-015 open) | IMPLEMENTED, TESTED | `decisionPayout.test.ts`, `attackSuite` 07/13/16–19/24 |
| API7 Server Side Request Forgery | no route fetches a caller-supplied URL | NOT APPLICABLE today | code review |
| API8 Security Misconfiguration | `ENVIRONMENT = "production"` default keeps demo login and docs off; CORS allowlist; secure headers; generic errors; secrets only in `.dev.vars` / `wrangler secret`; no `[env.production]` block yet | PARTIAL (BACKEND-SEC-018) | `hardening.test.ts`, `demoAuth.test.ts` |
| API9 Improper Inventory Management | one mounted API; OpenAPI regenerated from it; Postman updated; unmounted MVC layer moved to `backend/legacy/` outside the build; stubs listed as stubs | IMPLEMENTED | `API_CONTRACT.md`, `backend/legacy/README.md` |
| API10 Unsafe Consumption of APIs | screening signals come from an offline pipeline via SQL import, validated on read (range, enum, version) and never trusted for decisions; no third-party API is called by the Worker | IMPLEMENTED, TESTED | `screeningSignals.test.ts`, `quantumScreening.test.ts` |

## 4. Trust boundaries the frontend relies on

| Frontend may | Frontend may not (backend enforces) |
|---|---|
| show or hide buttons by role | perform an action its token's role or tenant does not allow (403/404) |
| send `policyId`, `category`, narrative, incident date, payout inputs, files, a decision outcome/reason/amount | send identity, role, tenant, stage, status, scores, band, recommendation, digest or a payout amount (400 or ignored) |
| display the risk signal to staff | show the risk signal to customers (route is staff-only, 403) |
| display the integrity result | obtain `MLDSA_SEED` or the private key (never leaves the Worker) |

## 5. Secrets

| Secret | Where | Never in |
|---|---|---|
| `JWT_SECRET`, `MLDSA_SEED` | `backend/.dev.vars` (gitignored, generated by `npm run setup:local`, values never printed) or `wrangler secret put` | git, README, Postman, Flutter, tests (vitest generates per-run values), logs, audit rows |
| `DEMO_LOGIN_PASSWORD` (local demo accounts, `1234567`) | `backend/.dev.vars`; only the seed script and the test setup read it | the Worker, audit rows, tokens |
| password hashes | `users.password_hash` (PBKDF2-SHA256, 100 000 iterations, 16-byte salt) | any API response |

`git ls-files` shows no `.dev.vars`, `.env`, Postman environment or key material. The Flutter client no longer reads
`LOGO_DEV_SECRET_KEY`.

## 6. Remaining limitations

Identity provider, key rotation and token revocation (019) · password reset / MFA · per-environment wrangler config (018) ·
decider and payer may be the same manager (015) · appeal limit (016) · `Withdrawn`/`Expired` without routes · rate limiter is approximate ·
audit and decision tables are append-only by trigger, which a database administrator can drop (the ML-DSA
signature then still detects decision changes; audit rows are not signed) · single shared demo password ·
deployed Worker state unknown (§1).

## 7. Merge with main `abc3a3d` (26 Sep 2026)

| Item on main | Action |
|---|---|
| `actor.ts` switched to `decode()` (no signature, issuer or TTL check): any forged token accepted | **Reverted** to the verifying `actor.ts`; covered by `auth.test.ts`, ATTACK-02/25 |
| Magic-word `/profile/login` | Removed; real accounts |
| `admin.ts` using `tenants.created_at` (no such column) and the removed ADMIN role | Replaced by the tested `admin.ts` |
| Nightly cron updating claims directly (no state machine, no audit) | Rewritten as `jobs/expireInfoNeeded.ts` (SYSTEM edge, conditional update, audit row); `expiryJob.test.ts` |
| Ansa payout: calls the provider, then inserts `status='paid'` (violates the CHECK) → money moves with no record, retry pays again | Removed; comment lists what a safe integration needs |
| `[ai]` binding: forces a remote session, so tests and `wrangler dev` fail without a Cloudflare API token | Commented out with instructions; OCR skips itself when AI is unbound |
| `*.orig` / `*.patch` files in `backend/src`, `patch_*.mjs` at the root, re-tracked `frontend/build` | Deleted / moved to `scripts/maintenance/` / untracked |
| Kept | OCR queue consumer + `0009_evidence_ocr.sql`, customer `/withdraw` route, messaging stub, scripts move |
