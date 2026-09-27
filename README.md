# EasyClaim

EasyClaim is a claims platform concept for South African insurance customers (GKHack26, Cyber + Quantum track).
Five roles: **customers** file and track claims; each insurer's **assessors** verify, screen and review them and its
**managers** decide and pay; the **insurer admin** manages that insurer's staff; a **superadmin** runs the platform
(insurers, insurer admins, stats). Admins never touch a claim. Security surrounds every step: the backend is authoritative and the app
is only its interface.

```
Customer ─► authenticated claim ─► evidence ─► screening ─┬─ classical anomaly model
                                                          └─ quantum-kernel signal (advisory)
        ─► human review ─► decision ─► ML-DSA-65 signature ─► verified decision ─► payout (simulated) ─► audit
```

## Repository

| Path | What |
|---|---|
| `admin/` | Insurer portal (React 19 + TypeScript + Vite) for assessors & managers, real sign-in; live at easy-claim-admin-frontend.pages.dev |
| `backend/` | Cloudflare Worker (Hono) + D1 + R2 + queue. The only API. Tests in `backend/test` |
| `frontend/` | Flutter app: one app for every role, routed after sign-in (`lib/main.dart`); live at easy-claim-frontend.pages.dev |
| `quantum/` | Offline Phase 4 screening pipeline (Python, PennyLane simulator) that exports signals for D1 |
| `docs/` | Architecture, API contract, security, phase reports, demo runbook |
| `backend/legacy/`, `scripts/python_migration/` | Not part of the app (unmounted legacy code, one-shot scripts) |

Start here: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/API_CONTRACT.md](docs/API_CONTRACT.md) ·
[docs/DEMO_RUNBOOK.md](docs/DEMO_RUNBOOK.md) · [docs/SECURITY_INTEGRATION.md](docs/SECURITY_INTEGRATION.md) ·
[docs/INTEGRATION_REPORT.md](docs/INTEGRATION_REPORT.md).

## Quick start (local)

```bash
cd backend
npm install
npm run setup:local        # backend/.dev.vars with JWT_SECRET, MLDSA_SEED and the demo password
npm run demo:setup:local   # migrations 0001-0015, seed, demo accounts, quantum signals, demo claims
npm run dev                # http://127.0.0.1:8787 (port busy? see the runbook)

cd ../frontend
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://127.0.0.1:8787/api/v1

# Or run the React Insurer Admin Portal:
cd ../admin
npm install
npm run dev                    # http://localhost:5173
```

Sign in with a demo account, password `1234567` (local demo only): `mike` (customer), `assessor_discovery`,
`manager_discovery`, `admin_discovery` (Discovery staff), `superadmin`. The same accounts work on live; deploy with
`npm run deploy:live` (see the runbook). Or register a new customer from the sign-in screen. Offline tokens for Postman/curl:
`npm run token -- --demo` or `--postman`.

## Checks

```bash
cd backend && npm run typecheck && npm test && npm audit
cd frontend && flutter analyze && flutter test
cd backend && npm run quantum:test          # needs quantum/.venv (see quantum/README.md)
bash docs/integration/live-demo.sh          # against a running local Worker
```

## Status

| Capability | Status | Where |
|---|---|---|
| Accounts + authentication | IMPLEMENTED: `users` table with PBKDF2 passwords; login / register / me; HS256 JWT verified by the Worker (pinned alg, iss/aud, exp/iat, per-role TTL, fail closed). account re-checked on every request (disabling or a password change revokes tokens at once), password change, login lockout. Reset, MFA, identity provider PLANNED | `backend/src/endpoints/auth.ts`, `backend/src/security/actor.ts` |
| Roles + administration | IMPLEMENTED: CUSTOMER / ASSESSOR / MANAGER / INSURER_ADMIN / SUPERADMIN; insurers apply and the superadmin approves; superadmin manages insurers and insurer admins (no claim access); insurer admin manages its staff, policy-link requests and required documents | `backend/src/endpoints/admin.ts` |
| Authorization + tenants | IMPLEMENTED: role per route and per transition; owner / same-tenant object checks (404 when not allowed); superadmin has no claim access; strict schemas | `backend/src/security/*` |
| Claim lifecycle | IMPLEMENTED: Draft → Submitted → Verified → Screening → Review → Decision → Paid; Info Needed (staff message, customer reply), Appeal (reason stored), Withdraw; a message thread per claim | `claimStateMachine.ts` |
| Evidence | IMPLEMENTED: private R2, PDF/JPEG/PNG ≤ 10 MiB, magic bytes, SHA-256, VALID/TAMPERED check | `endpoints/evidence.ts` |
| Screening (Phase 4) | IMPLEMENTED, advisory: classical + quantum-kernel anomaly signal (simulator, synthetic data). Did **not** beat the classical baseline | `quantum/`, `backend/src/screening/`, `docs/quantum/` |
| Decisions + PQC (Phase 3, 5) | IMPLEMENTED: MANAGER only, insert-only record, ML-DSA-65 signature, verify route, payout refuses a decision that no longer verifies | `claimsInsurer.ts`, `security/integrity.ts` |
| Payout | IMPLEMENTED, **simulated** (no payment rail) | `/claims/:id/pay` |
| Audit | IMPLEMENTED: append-only `audit_events` for changes and refusals | `security/audit.ts` |
| Flutter app | IMPLEMENTED against the real API (customer app with registration, assessor/manager claim portal, insurer-admin team portal, superadmin portal) | `frontend/lib` |
| Customer onboarding | IMPLEMENTED: EasyClaim ID per customer, encrypted profile (SA ID checked), policy-link requests with per-insurer required documents; insurer admin reviews (ID masked, reveal audited) | `backend/src/onboarding/` |
| POPIA consent | IMPLEMENTED: after the document check (onboarding and claim Verify) the customer signs the insurer's own consent / mandate form (name + password, sealed with ML-DSA-65); approval and screening wait for it; withdrawal stops further work | `backend/src/consent/` |
| Stubs | Removed 27 Sep 2026: `/client/*`, `/profile`, `/activities/*`, `/ocr/process` now answer 404 | `docs/API_CONTRACT.md` |

Open decisions and planned work: [docs/security/BACKEND_SECURITY_HANDOFF.md](docs/security/BACKEND_SECURITY_HANDOFF.md)
(appeal limit, identity provider, per-environment config, decider = payer).
