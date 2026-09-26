# EasyClaim Phase 4 — Quantum Screening

Date: 2026-09-26 · Branch `phase-4-completion` (from `main` @ `73aee43`) · **Uncommitted, awaiting approval.**
Status words: IMPLEMENTED · TESTED · PARTIALLY IMPLEMENTED · PLANNED. Original experiment report:
`docs/quantum/PHASE_04_REPORT.md`; completion precheck: `PHASE_04_COMPLETION_PRECHECK.md`.

## 1. Objective
Add one small, credible quantum-kernel anomaly signal to Screening, compared honestly with a classical baseline, as
advisory context for a human reviewer — without weakening any Phase 0–3 control.

## 2. What Phase 4 Originally Planned
Master plan §10: quantum computing belongs in SCREENING as an experimental risk signal; feature map → quantum kernel →
classical learner; a classical baseline on the same features; predefined metrics; simulator vs hardware recorded;
no superiority claim without measurement.

## 3. What Was Already Implemented (merged `983c928`, verified)
Offline Python pipeline (PennyLane 0.45.1, 5 qubits, simulator), classical RBF one-class SVM, quantum fidelity-kernel
one-class SVM on identical features, synthetic dataset, SQL export, `screening_signals` (0006), read-only
`GET /risk-signals`, signal attached after `/screen`, 26 pytest + 7 vitest tests, architecture/precheck/report docs.

## 4. Completion Gap (closed in this change)
No screening recommendation or brief-style band; only a model version; no audit of the signal; decision did not record
the signal; stored signals editable in place; demo claims' scores copied, not computed; unpinned dependencies; npm script
bypassed the venv; three doc inaccuracies; no explicit fake-score / bypass / end-to-end tests; no Postman/OpenAPI entry.

## 5. Final Architecture
```
Customer → Authentication → Tenant / RBAC → Claim → Evidence → SCREENING
                                                         ├─ classical one-class SVM (RBF)      ┐ same 5 features,
                                                         └─ quantum-kernel one-class SVM        ┘ offline, simulator
                                                         → anomaly signal (advisory, audited, digest)
   → HUMAN REVIEW → DECISION (records the signal it saw) → Phase 5: ML-DSA integrity (PLANNED) → PAYOUT → AUDIT
```
Quantum computation stays out of the Worker: scores are computed offline and imported; the Worker only reads.

## 6. Feature Pipeline
Five features from real `claims` columns (days to report, category, prior claims, narrative length, submission hour),
reference-fitted imputation, log1p, min-max, soft clip, ×π for angles. Details: `docs/quantum/FEATURE_PIPELINE.md`. IMPLEMENTED, TESTED.

## 7. Classical Baseline
`OneClassSVM(kernel='rbf', gamma='scale', nu=0.1)` on the scaled features. IMPLEMENTED, TESTED.

## 8. Quantum Kernel
ZZ-style feature map (H, RZ(x), CNOT-RZ(x_i x_j / π)-CNOT) × 2 reps on 5 qubits; fidelity kernel |⟨φ(y)|φ(x)⟩|²;
validated (symmetric, unit diagonal, [0,1], PSD); cross-checked against the overlap circuit. Simulator only. IMPLEMENTED, TESTED.

## 9. Anomaly Detection
One-class SVM with a precomputed kernel; scores as reference percentiles; bands NORMAL / ELEVATED / HIGH
(stored as NORMAL / UNUSUAL / HIGH_ANOMALY); recommendation STANDARD_REVIEW / REVIEW_REQUIRED. No fraud labels, no
fraud verdicts. IMPLEMENTED, TESTED.

## 10. Backend Integration
`POST /claims/:id/screen` (after the transition) and `GET /claims/:id/risk-signals` return
`{ classicalAnomaly, quantumAnomaly, interpretation, anomalyBand, screeningRecommendation, explanation, versions,
signalDigest, execution, computedAt, advisory: true }`; both write an audit event; `/decide` stores the signal summary in
`claim_decisions.risk_signal`. Import: `npm run signals:import:local` / `demo:quantum:local` (local only). IMPLEMENTED, TESTED.

## 11. Security Boundary
Auth → role → strict params → tenant/ownership → (transition) → read → audit. No write route, strict bodies, no
transition authority, tamper-evident storage (migration 0007 blocks in-place UPDATE; digests in audit and decision).
`docs/quantum/QUANTUM_SECURITY_BOUNDARY.md`. IMPLEMENTED, TESTED.

## 12. UI Integration
PLANNED (user decision). The Flutter app has no insurer screen and no API client; the signal is demonstrated through the
API and Postman. When a UI is built it must show both scores as signals, the recommendation, and "a human decides".

## 13. Tests
Python (`npm run quantum:test`): **27 passed** (26 existing + demo-claims-scored). Vitest (`npm test`): **16 files,
246 passed** (232 before + 14 in `test/quantumScreening.test.ts`). Mapping: QUANTUM-01 determinism (`test_kernel_is_deterministic`,
`test_scores_reproducible`, `test_generator_is_deterministic_and_labelled`); 02 classical runs and 03 quantum kernel runs
(`test_kernel_and_models.py`); 04 bounds (`test_scores_bounded`, kernel validity, DB CHECKs); 05 missing/invalid features
(`test_features_preprocessing.py`, reader stub test); 06 other customer (403); 07 cross-tenant (404, audited); 08 fake scores
(4 cases); 09 high anomaly does not reject; 10 audit + decision snapshot; 11 all Phase 0–3 suites green; 12 normal claim flow.

## 14. Attack Tests
| Attack | Result | Evidence |
|---|---|---|
| 1 Fake score (`quantumScore: 0`, `"LOW"`, fake `riskSignals`) | ignored on `/screen`, 400 on `/decide`, 404 on any write to `/risk-signals`; stored row unchanged | tests + live log |
| 2 Cross-claim (other customer) | 403 | tests + live log |
| 3 Cross-tenant | 404, audited `cross_tenant` | tests + live log |
| 4 Result manipulation | in-place UPDATE aborts; re-import changes the digest vs the audited one | tests |
| 5 Quantum → Paid / Rejected | 409 `illegal_transition` from Screening; outcome only via review → MANAGER decision | tests + live log |
Live evidence: `docs/quantum/evidence/PHASE_04_COMPLETION_LIVE_DEMO.log`.

## 15. Classical vs Quantum Results
Synthetic anomalies in top 16: classical 9, quantum 8; Spearman 0.837; quantum ~75–100× slower on the simulator.
Quantum does **not** outperform classical. `docs/quantum/CLASSICAL_VS_QUANTUM.md`.

## 16. Demo Flow
Import signals → assessor `/screen` on `claim_demo_normal` (NORMAL, STANDARD_REVIEW) → `/screen` on `claim_demo_unusual`
(HIGH, REVIEW_REQUIRED) → fake-score and bypass attempts refused → review → manager decides with their own reason →
decision view; audit shows `screening.signal_attached` / `signal_read` with the same digest stored in the decision.
Script: `docs/quantum/evidence/live-demo-p4-completion.sh`. Say: "The quantum component does not decide whether this is
fraud. It flags unusual patterns as a screening signal; the decision stays with EasyClaim's authorization and human review."

## 17. What Is Actually Implemented
Everything in §§6–11 and §§13–14, on the simulator, with synthetic reference data, offline scoring, local import.

## 18. What Is Partially Implemented
Scoring of real claims: the pipeline scores the three seed claims, whose features are mostly missing; there is no scheduled
or on-demand scoring of new claims (a new claim shows `riskSignals: null` until the next offline run is imported).

## 19. Remaining Limitations
Synthetic reference population; five weak features; no amount/evidence features; noise-free statevectors (no shot noise,
no hardware); in-sample percentiles for reference rows; local-only import scripts; signal replacement is detectable but
not cryptographically prevented; no UI.

## 20. What We Can Honestly Claim
"EasyClaim attaches an experimental quantum-kernel anomaly signal to claims at Screening, computed on a simulator with the
same features as a classical baseline. It performed about the same as the classical baseline on synthetic data and was
slower. It is advisory, audited and tamper-evident, and it cannot approve, reject, pay or move a claim."

## 21. Phase 4 → Phase 5 PQC Handoff
`claim_decisions` now carries `risk_signal` (band, scores, model, execution, digest) next to `evidence_digest`, amounts,
destination hash and `rules_version`. Phase 5 should canonicalise that decision bundle, sign it with ML-DSA (FIPS 204,
candidate ML-DSA-65) into the reserved `integrity_signature`, add `GET /claims/:id/decision/verify` (VALID / TAMPERED), make
`/pay` refuse an unverifiable decision, and settle key management (DECISION REQUIRED). The screening digest makes a later
signal replacement verifiable against the signed decision.
