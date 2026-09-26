# EasyClaim Phase 4 Precheck — Quantum Screening

Date: 2026-09-26 · Branch: `phase-4` (worktree `ec-phase4`) · Base: `main` `685b3de` · Author: quantum track (Claude, instructed)

Status vocabulary: IMPLEMENTED · PARTIAL · NOT IMPLEMENTED · PLANNED · BLOCKED · DECISION REQUIRED.
Every statement points at a file that was read before Phase 4 changed anything.

## 1. Existing claim features available

`claims` table after migrations 0001–0003 (`migrations/0001_init.sql`, `0002_security.sql`, `0003_tenants.sql`):

| Column | Type | Written by | Usable as a feature |
|---|---|---|---|
| `id` | TEXT PK | server (`claim_<uuid>`) | identifier only |
| `user_id` | TEXT | server from token | yes, indirectly: count of claims per user |
| `policy_id` | TEXT | validated request | join key only (policies have no start date or premium) |
| `tenant_id` | TEXT FK | server from policy | no (isolation boundary, not a risk feature) |
| `stage`, `status` | TEXT | state machine only | no (workflow state must not feed the model) |
| `category` | TEXT enum (Medical, Vehicle, Life, Property, Other) | validated request | yes |
| `cause_of_loss` | TEXT ≤ 2000 chars | validated request | yes, as a length/completeness proxy only |
| `incident_date` | ISO date, not in the future | validated request | yes, with `created_at` |
| `created_at`, `updated_at` | ISO datetime | server | yes (`created_at`) |

Related tables: `policies` (id, user_id, plan_name, status, tenant_id), `evidence` (created in 0002, **unused by any route**, `src/endpoints/claims.ts` only queues an event), `audit_events` (append-only).

## 2. Existing screening functionality

- Customer: `PATCH /api/v1/claims/:claimId/screening` stores `causeOfLoss` and `incidentDate` while the claim is `Draft` or `Info Needed` (`src/endpoints/claims.ts`). No scoring.
- Insurer: `POST /api/v1/claims/:claimId/screen` moves `Verified → Screening` through `transitionClaim` (`src/endpoints/claimsInsurer.ts`). No scoring, no rules, no risk field. `/request-info` and `/review` move the claim on.
- There is no fraud, risk or anomaly logic anywhere in `src/` (grep for `risk|fraud|anomaly|score`: only the mass-assignment test rejects a client-sent `riskScore`).

## 3. Existing screening API contract

`POST /screen` → `200 { status: 'transitioned', claimId, from, to: 'Screening' }`; `404` for unknown / other-tenant / draft claims; `403` wrong role; `409` illegal transition; `401` no token. Order of checks: `requireActor → validate params → requireRole(ASSESSOR, MANAGER) → loadAuthorizedClaim('insurer') → transitionClaim → audit`.

## 4. Existing fields usable as quantum features (chosen: 5)

| Feature | Derived from | Note |
|---|---|---|
| `days_to_report` | `created_at − incident_date` | missing when either is NULL (all three seed claims) |
| `category_index` | `category` | ordinal over the 5-value enum; one-hot would need 5 qubits on its own |
| `prior_claim_count` | other rows with the same `user_id` in the scored population | computed at scoring time, not stored |
| `narrative_word_count` | `cause_of_loss` | completeness proxy; not a text model |
| `submission_hour` | `created_at` (UTC hour) | behavioural feature; timezone caveat documented |

## 5. Missing data

NOT AVAILABLE in the repository, therefore not used and not fabricated: claim amount, policy start/age, premium, payout history, evidence count and hashes (Phase 2 will create the rows), claimant demographics, geography, device or channel. Listed as future features in `PHASE_04_REPORT.md` §17.

## 6. Do real fraud labels exist?

**No.** `claims.status` holds `Pending / Processing / Approved / Rejected`, which is a workflow outcome and not a fraud label. The seed (`seed_sa_data.sql`) has three demo claims. No dataset, notebook or CSV with labels exists anywhere in the repo. Consequence: supervised classification is out; the experiment is one-class anomaly detection on a clearly-labelled **synthetic** development dataset.

## 7. Proposed quantum experiment

Classical features → shared preprocessing → (a) one-class SVM with RBF kernel, (b) 5-qubit quantum feature map → fidelity kernel → one-class SVM on the precomputed kernel. Same features, same preprocessing, same reference population, same percentile-based score, same bands. Simulator only (PennyLane `default.qubit`). Details in `QUANTUM_SCREENING_ARCHITECTURE.md`.

## 8. Integration limitations

- The Worker runs on Cloudflare (V8). Qiskit/PennyLane are Python and cannot run inside it. Signals are computed offline and imported into a server-only table; the Worker reads them.
- No claim amount exists, so the most common insurance risk feature is absent.
- `prior_claim_count` depends on the population scored together; in production it would be a per-tenant SQL count at scoring time.
- Percentile scores are relative to the synthetic reference population, not to real EasyClaim traffic.
- Phase 2 (evidence) and Phase 3 (decisions) run in parallel; Phase 4 touches `claimsInsurer.ts` only inside the `/screen` handler and adds a mount line in `index.ts`, per `docs/PARALLEL_WORK.md`.

## 9. Dependencies

Python 3.13 with `pennylane 0.45.1`, `scikit-learn 1.9.1`, `numpy 2.5.3`, `pytest` (local venv `quantum/.venv`, gitignored). No new npm dependency. No cloud account, no API key, no network access required.

## 10. What will NOT be implemented

Quantum optimisation / QUBO assessor scheduling (teammate's proposal; recorded as future research), supervised fraud classification, fabricated labels, real-hardware execution (no credentials; would be optional and clearly labelled), any quantum influence on authentication, authorization, tenant isolation, the state machine, decisions or payouts, a new microservice, a UI (Flutter app is the backend team's; the API response carries an explanation string for it), changes to Phase 2 or Phase 3 files.

DECISION REQUIRED (for the team, not resolved here): whether customers may ever see a customer-facing version of the signal; the current route is insurer-only. Whether the master plan (`EasyClaim_Cyber_Quantum_Master_Source_of_Truth.docx` §10, §21) is updated to record "one-class anomaly kernel" as the chosen Phase 4 method.
