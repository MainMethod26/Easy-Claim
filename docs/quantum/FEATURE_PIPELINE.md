# Feature pipeline (claim-features-v1)

Code: `quantum/easyclaim_quantum/features.py`, `preprocessing.py`. Used identically by the classical baseline and the
quantum kernel. Features are derived server-side from authoritative `claims` rows; no client ever supplies a feature,
a scaled value or a score.

## Features (order = qubit order)

| # | Feature | Derived from | Missing / invalid |
|---|---|---|---|
| 0 | `days_to_report` | `created_at` date − `incident_date` | NaN (negative → NaN) → reference median |
| 1 | `category_index` | ordinal index in (Medical, Vehicle, Life, Property, Other) | NaN → median; unknown category raises |
| 2 | `prior_claim_count` | other claims of the same `user_id` in the scored population | NaN if no user → median |
| 3 | `narrative_word_count` | word count of `cause_of_loss` | **0 words** (not imputed) |
| 4 | `submission_hour` | UTC hour of `created_at` | NaN → median |

Deliberately not used (no column exists or would add noise without labels): claim amount, policy age, evidence counts,
customer history beyond prior claims. Adding any of them is a new feature version.

## Preprocessing (fitted on the reference population only)

1. Impute NaN with reference medians `[6, 1, 2, 25, 12]`.
2. `log1p` on columns 0, 2, 3 (after clipping at 0).
3. Min-max to the reference range: min `[0.6931, 0, 0, 2.1972, 7]`, max `[3.8286, 4, 1.6094, 3.7842, 21]` (a constant column maps to 0).
4. Soft clip: the reference range maps to `[0, 0.75]`; values above it map into `(0.75, 1)` via `0.75 + 0.25·(1 − e^{−(s−1)})`.
5. Classical model: the scaled vector. Quantum model: the same vector × π as rotation angles.

The fitted parameters are written to `quantum/results/results.json` (`preprocessing`), so a run is reproducible.

## Scores and bands

Both models output `-decision_function`, converted to the percentile of the reference population's raw scores (`[0, 1]`).
The band comes from the quantum score: NORMAL < 0.80 ≤ UNUSUAL (API `ELEVATED`) < 0.95 ≤ HIGH_ANOMALY (API `HIGH`).
By construction about 5 % of normal reference claims land in HIGH — the signal asks for review, it does not accuse.

## Versions

`model = phase4-qk1c-v1`, `features = claim-features-v1`, `kernel = qk-fidelity-zz-r2-v1` (recorded in `results.json`,
each exported `feature_snapshot`, and the API's `riskSignals.versions`), Worker contract `screening = phase4-screening-v1`.

## Tests

`quantum/tests/test_features_preprocessing.py` (13 cases: extraction, missing values, invalid input, duplicates, bounds,
constant columns, ordering above range) and `test_dataset_and_export.py` (demo claims scored from their own features).
