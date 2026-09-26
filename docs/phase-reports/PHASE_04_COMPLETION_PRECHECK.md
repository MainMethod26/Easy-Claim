# Phase 4 Completion Precheck

Date: 2026-09-26 · Base: `main` @ `73aee43` (Phases 0–4 + cyber alignment) · Work branch: `phase-4-completion` (worktree `ec-phase4`)
Method: three read-only inspections of `quantum/`, `src/screening/`, `/screen`, migrations, tests, Flutter `lib/` and
all Phase 4 docs, verified against the code (not the earlier report). Nothing was changed before this file.

## 1. Intended Phase 4 Architecture
Claim → existing claim features → preprocessing → { classical one-class baseline, quantum-kernel one-class model } →
anomaly signal → Screening → human review → human decision. Advisory only: never approves, rejects, pays, transitions,
or bypasses authentication, RBAC, tenant isolation or ownership.

## 2. What Already Exists
- `quantum/` (Python, PennyLane 0.45.1, scikit-learn 1.9.1, numpy 2.5.3 in `quantum/.venv`): `features.py`, `preprocessing.py`,
  `classical.py`, `quantum_kernel.py`, `model.py`, `dataset.py`, `experiment.py` (`MODEL_VERSION = phase4-qk1c-v1`),
  committed synthetic dataset `data/dev_claims.json`, results in `results/` (JSON, Markdown, two SQL exports), 26 pytest tests.
- Worker: `migrations/0006_screening_signals.sql`, `src/screening/quantumSignal.ts` (`readRiskSignals`),
  `src/screening/routes.ts` (`GET /claims/:id/risk-signals`), one read call in `POST /claims/:id/screen`.
- 7 vitest tests (`test/screeningSignals.test.ts`); docs `docs/quantum/PHASE_04_PRECHECK.md`, `PHASE_04_REPORT.md`,
  `QUANTUM_SCREENING_ARCHITECTURE.md`, `evidence/PHASE_04_LIVE_DEMO.log`.

## 3. What Is Working
- One-class anomaly detection, no fabricated fraud labels (labels exist only on rows marked `synthetic: true`).
- Identical 5-feature representation for both models; preprocessing fitted on the reference population only.
- Fidelity quantum kernel with symmetry / unit-diagonal / [0,1] / PSD validation and a circuit cross-check.
- Offline scoring → SQL import; the Worker only reads; no route accepts a score; tenant-scoped read (404 cross-tenant,
  403 customer, 401 no token); a signal row changes nothing on the claim.

## 4. What Is Partially Implemented
- Output: `classicalAnomaly`, `quantumAnomaly`, `interpretation`, `explanation`, `advisory` — but no screening
  recommendation and a band vocabulary that differs from the brief (NORMAL / UNUSUAL / HIGH_ANOMALY).
- Versioning: only `model_version`; no feature, kernel or screening version.
- "High anomaly does not force or block the workflow": only shown as "row unchanged", not end to end.

## 5. What Is Missing
- Audit of the screening signal (neither attach on `/screen` nor `GET /risk-signals` is recorded).
- The decision does not record what screening showed (`claim_decisions.risk_signal`, reserved in Phase 3, stays NULL).
- Tamper evidence for stored signals (no triggers, no provenance, `INSERT OR REPLACE` import).
- Explicit attack tests: fake score with value `0` / `"LOW"` on every relevant route; quantum → Paid/Rejected bypass.
- Postman and OpenAPI entries for `/risk-signals`.

## 6. What Is Broken
- The two demo claims do not carry their own scores: `demo_claims.sql` copies the scores of two synthetic rows.
- Doc inaccuracies: the reference maximum of prior claims is 4 (not 2); "max abs diff 0.00e+00" is a rounding to 1e-10;
  seed claims have no narrative, which is encoded as 0 words (not imputed), pushing them towards "minimal narrative".
- Reproducibility: `requirements.txt` has minimum versions only; `npm run quantum:experiment` uses the PATH Python, not the venv.
- The reader's defensive branch is untested (DB CHECKs stop malformed rows first).

## 7. Current Quantum Implementation
PennyLane `default.qubit` statevector simulator, 5 qubits (one per feature), ZZ-style feature map (H, RZ(x), CNOT–RZ(x_i x_j / π)–CNOT)
repeated twice, fidelity kernel |⟨φ(y)|φ(x)⟩|², sklearn `OneClassSVM(kernel="precomputed", nu=0.1)`. No hardware.

## 8. Current Classical Baseline
sklearn `OneClassSVM(kernel="rbf", gamma="scale", nu=0.1)` on exactly the same scaled matrix. Scores for both models are
converted to percentiles of the reference population's raw scores.

## 9. Current Feature Set
`days_to_report` (created_at − incident_date), `category_index`, `prior_claim_count` (same user in the scored population),
`narrative_word_count` (cause_of_loss), `submission_hour` (UTC). All derived from real `claims` columns. Not used (and
not invented): claim amount, policy age (no column), evidence features.

## 10. Current Data Availability
No real claim history and no fraud labels. Seed claims (3) lack category, dates and narrative. Reference data is a
committed synthetic set: 120 normal rows, 16 synthetic anomalies (late report ×4, serial claimant ×8, night + minimal narrative ×4).

## 11. Current Backend Integration
Behind `requireActor` → `requireRole('ASSESSOR','MANAGER')` → `validate` → `loadAuthorizedClaim(…,'insurer')`. `/screen` reads the
signal **after** its transition; `GET /risk-signals` reads it only. No write path, no online scoring, local import scripts only.

## 12. Current Frontend Integration
None. Flutter (`lib/`) has no insurer screen and no API client; all data is mock. **User decision: no UI in this completion;
demo via API + Postman; UI integration PLANNED.**

## 13. Current Tests
Python 26 (dataset/export 3, features/preprocessing 13, kernel/models 10). Vitest 7 in `screeningSignals.test.ts` within a 232-test suite.

## 14. Phase 4 Completion Gap
Recommendation + band + versions in the output; audit of attach/read; signal snapshot in the decision; tamper evidence;
explicit attack and end-to-end workflow tests; demo claims scored from their own features; pinned dependencies and venv
script; doc corrections; Postman/OpenAPI; completion docs, report and master plan update.

## 15. Recommended Minimal Implementation
Keep the offline architecture. Extend `readRiskSignals` (band, recommendation, versions, SHA-256 signal digest); audit
`screening.signal_attached` / `screening.signal_read` with the digest; store the signal JSON in `claim_decisions.risk_signal`
at `/decide`; migration 0007 adds an import timestamp and blocks in-place UPDATEs; score demo claims properly; pin
dependencies; add the attack/workflow tests; write the completion docs. No new lifecycle, no new authorization, no UI.
