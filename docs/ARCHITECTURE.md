# EasyClaim architecture (after the integration pass, 26 Sep 2026)

One application: a Flutter client, one Cloudflare Worker API, one D1 schema, one offline quantum pipeline.

**Roles (team decision, 26 Sep 2026):** `CUSTOMER` (platform-level, self-registers, holds policies with several insurers),
`INSURER_ADMIN` (the insurance owner's admin: one role per insurer/tenant that verifies, screens, reviews, decides and pays
its own tenant's claims and manages its own admin accounts), `SUPERADMIN` (platform operator: creates insurers and their
admins, sees platform stats and a read-only cross-tenant claim list; never acts on a claim).
Contract: [API_CONTRACT.md](API_CONTRACT.md). Security view: [SECURITY_INTEGRATION.md](SECURITY_INTEGRATION.md).
How to run it: [DEMO_RUNBOOK.md](DEMO_RUNBOOK.md).

## Repository map (one place per responsibility)

| Responsibility | Canonical location |
|---|---|
| Frontend (UI only) | `frontend/` (Flutter). `lib/core/api` (one API client), `lib/core/auth` (session), `lib/data/models` (JSON mapping + stage mapping), `lib/data/repositories`, `lib/screens`, `lib/widgets`, `lib/providers` |
| Backend API | `backend/src/` — `index.ts` (middleware + mounts), `endpoints/*` (routes), `security/*` (auth, RBAC, object access, state machine, audit, evidence, ledger, ML-DSA), `screening/*` (signal reader), `integrity/*` (decision verify, public key) |
| Authentication + accounts | `backend/src/security/actor.ts` (`requireActor`, the only place identity is established); `backend/src/endpoints/auth.ts` (login, register, me) over the `users` table (migration 0009) with PBKDF2 hashes (`security/password.ts`) |
| Administration | `backend/src/endpoints/admin.ts` (`/admin/*` SUPERADMIN, `/tenant/*` INSURER_ADMIN) |
| Claim lifecycle | `backend/src/security/claimStateMachine.ts` + `claimAccess.ts` (`transitionClaim`) |
| Screening | offline `quantum/` (Python) → `quantum/results/*.sql` → D1 `screening_signals` → read-only `backend/src/screening/` |
| Decisions + PQC | `backend/src/endpoints/claimsInsurer.ts` + `backend/src/security/integrity.ts` (ML-DSA-65, `@noble/post-quantum`) |
| Database | `backend/migrations/0001..0008` (only schema source); demo data `backend/seed_sa_data.sql` + `quantum/results/*.sql` |
| Tests | `backend/test` (vitest in the Workers runtime), `frontend/test` (flutter_test), `quantum/tests` (pytest) |
| API docs | `docs/API_CONTRACT.md`, `backend/src/openapi.json` (served at `/swagger` outside production), `backend/EasyClaim.postman_collection.json` |
| Not part of the app | `backend/legacy/` (unmounted MVC layer, legacy schema), `scripts/python_migration/` (one-shot patch scripts) |

## Request path

```
┌──────────────────────── Flutter app (UNTRUSTED client) ─────────────────────────┐
│ screens → providers/view state → repositories → ONE ApiClient                    │
│ role-based navigation is UX only; it never grants anything                       │
└──────────────────────────────┬───────────────────────────────────────────────────┘
                               │ HTTPS/HTTP  Authorization: Bearer <JWT>
┌──────────────────────────────▼──── Hono Worker (backend/src/index.ts) ───────────┐
│ request id → secure headers → CORS allowlist → body limit (64 KB / 10 MiB files) │
│ → per-IP rate limit                                                               │
│ → [POST /auth/login, POST /auth/register: the only routes without a token]         │
│ → requireActor: verify JWT → actor {id, role, tenantId} from the token only      │
│ → per-actor rate limit                                                            │
│ → requireRole (function level) → strict schema (property level)                  │
│ → loadAuthorizedClaim (object level: owner / tenant / drafts private → 404)      │
│ → transitionClaim (state machine + one D1 batch with its audit row)              │
└──────────────────────────────┬───────────────────────────────────────────────────┘
                               ▼
Customer claim ─► Evidence (R2, SHA-256) ─► Submitted ─► Verified ─► Screening ─► Review
                                                              │
                          Screening signal (ADVISORY)  ◄──────┘  read from D1, never written by the API
                          ├── classical anomaly (one-class RBF SVM)
                          └── quantum-kernel anomaly (PennyLane simulator)
                                                                        │
                                  Human review (INSURER_ADMIN) ────────────┘
                                                                        ▼
                                  Decision (INSURER_ADMIN) ─► ML-DSA-65 signature over the decision bundle
                                                        (amounts, destination hash, evidence digest,
                                                         screening signal seen, rules version)
                                                                        ▼
                                  Payout (INSURER_ADMIN, simulated) ─► verifies signature + destination first
                                                                        ▼
                                  audit_events (append-only) ─► D1
```

## Trust boundaries

- **The frontend is untrusted.** It can hide buttons; it cannot authorize. Every sensitive rule is enforced in
  `backend/src/security/*`. Headers such as `X-User-Id`, `X-Role`, `X-Tenant-Id` are ignored; body fields for
  identity, role, tenant, stage, status, scores or payout amounts are rejected by strict schemas.
- **The quantum signal is advisory.** It is produced offline, imported into D1, read by the Worker, shown to insurer
  staff, and recorded (digest) in the decision. It never changes stage, status, eligibility or payout. The measured
  experiment did not beat the classical baseline (synthetic anomalies in each model's top 16: quantum 8/16,
  classical 9/16, simulator only, synthetic data; see
  [quantum/CLASSICAL_VS_QUANTUM.md](quantum/CLASSICAL_VS_QUANTUM.md)), so no business rule relies on it.
- **The ML-DSA private key stays server-side.** It is derived from the `MLDSA_SEED` secret inside the Worker. Clients
  get verification results and, for outside verifiers, the public key only.
- **The database is not proof of a decision.** A stored decision counts only if its ML-DSA-65 signature still verifies.
  The signature detects later changes to signed decision data; it does not prevent someone with database access
  from changing it, and it does not cover data outside the signed bundle.
- **Accounts are real but minimal.** Username + PBKDF2 password in D1, 1-hour HS256 tokens. No revocation, reset or MFA yet;
  an identity provider can replace the issuer without touching `requireActor` (BACKEND-SEC-019).
- **Superadmin is not a super-user on claims.** It can create insurers and accounts and read, never verify, decide or pay.
- **One insurer role.** Merging assessor and manager removed the Phase 3 separation of duties (the same person can decide
  and pay). Recorded as a KNOWN LIMITATION; the audit trail still records who did each step.

## Stage model (backend is authoritative)

`Draft → Submitted → Verified → Screening → Review → Decision → Paid`, side states `Info Needed`, `Appeal`,
`Withdrawn` (no route yet), `Expired` (no job yet). The Flutter app maps these onto its six-step bar in one place
(`frontend/lib/data/models/claim_stage.dart`); see the table at the end of [API_CONTRACT.md](API_CONTRACT.md).

## Local topology

| Component | Command | Port |
|---|---|---|
| Worker + local D1/R2/queue (Miniflare) | `cd backend && npm run dev` | 8787 (use `-- --port 8790` if 8787 is taken, see the runbook) |
| Flutter web | `cd frontend && flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=...` | 5173 (must be in `ALLOWED_ORIGINS`) |
| Flutter Android emulator | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787/api/v1` | – |
| Quantum pipeline (offline) | `cd backend && npm run quantum:experiment` | – |
