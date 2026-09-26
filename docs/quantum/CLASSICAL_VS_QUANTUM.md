# Classical vs quantum: what was measured

Source: `quantum/results/results.json` (re-run for Phase 4 completion; model outputs identical to the original run,
only wall-clock times differ). **All data is synthetic** (`quantum/data/dev_claims.json`): 120 normal reference claims
and 16 synthetic anomalies (late report ×4, serial claimant ×8, night submission with minimal narrative ×4). There are
no real fraud labels anywhere. **Simulator only** (PennyLane `default.qubit`); no quantum hardware was used.

| Measure | Classical (RBF one-class SVM) | Quantum kernel (fidelity, 5 qubits, one-class SVM) |
|---|---|---|
| Same input features | 5 scaled features | the same 5, × π as angles |
| Synthetic anomalies in the model's top 16 | **9 / 16** | **8 / 16** |
| Mean score: reference / anomalies | 0.504 / 0.814 | 0.504 / 0.798 |
| Late report flagged (of 4) | 4 | 4 |
| Serial claimant flagged (of 8) | 2 | 3 |
| Night + minimal narrative flagged (of 4) | 4 | 1 |
| Runtime (this run) | 0.009 s fit + score | 0.66 s statevectors + 0.003 s kernel + 0.002 s fit |
| Agreement | Spearman rank correlation 0.837; top-16 overlap 0.44 | |
| Kernel validity | — | symmetric, unit diagonal, [0,1], PSD (min eigenvalue 1.8e-16); circuit cross-check within 1e-10 |
| Cost on hardware | — | 139 statevector simulations here; 23 460 circuits if every kernel entry ran on a device |

## Reading

- The quantum-kernel model does **not** outperform the classical baseline on this data. It is slightly better on one
  recipe (serial claimant), clearly worse on another (night + minimal narrative), and roughly 75–100× slower on a simulator.
- The two models agree strongly on ranking but disagree on which claims are the most unusual, which is why both scores
  are shown to the reviewer.
- Small synthetic data, five weak features and exact (noise-free) statevectors limit what this experiment can show.

## What we can honestly claim

"We use a quantum-kernel-based anomaly signal as an experimental screening input and compare it against a classical
baseline on identical features. On our synthetic evaluation it performed about the same as the classical baseline and
was slower." Not: "quantum is more accurate", "quantum detects fraud", or "quantum prevents fraud".
