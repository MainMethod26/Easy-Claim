"""EasyClaim Phase 4 experiment: classical one-class SVM vs quantum-kernel one-class SVM.

Run from the repository root:
    quantum/.venv/Scripts/python quantum/experiment.py            (Windows)
    quantum/.venv/bin/python quantum/experiment.py                (POSIX)

Writes to quantum/results/: results.json, results.md, screening_signals.sql, demo_claims.sql.
Simulator only. Same features, same preprocessing, same reference set for both models.
"""
from __future__ import annotations

import argparse
import json
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

from easyclaim_quantum.classical import ClassicalOneClass  # noqa: E402
from easyclaim_quantum.dataset import (  # noqa: E402
    ANOMALY_RECIPES,
    generate_dev_dataset,
    load_dev_dataset,
    load_seed_claims,
    save_dev_dataset,
    to_records,
)
from easyclaim_quantum.features import FEATURE_NAMES, N_FEATURES, extract_features  # noqa: E402
from easyclaim_quantum.model import EXPLANATIONS, QuantumOneClass, build_signal, percentile_scores  # noqa: E402
from easyclaim_quantum.preprocessing import Preprocessor  # noqa: E402
from easyclaim_quantum.quantum_kernel import QuantumFeatureMap, validate_kernel  # noqa: E402

MODEL_VERSION = "phase4-qk1c-v1"
FEATURE_VERSION = "claim-features-v1"
KERNEL_VERSION = "qk-fidelity-zz-r2-v1"


def spearman(a: np.ndarray, b: np.ndarray) -> float:
    ra = np.argsort(np.argsort(a))
    rb = np.argsort(np.argsort(b))
    if ra.std() == 0 or rb.std() == 0:
        return float("nan")
    return float(np.corrcoef(ra, rb)[0, 1])


def sql_str(v) -> str:
    return "NULL" if v is None else "'" + str(v).replace("'", "''") + "'"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--nu", type=float, default=0.10, help="one-class SVM nu for both models")
    ap.add_argument("--reps", type=int, default=2, help="feature-map repetitions")
    ap.add_argument("--seed", type=int, default=4, help="synthetic dataset seed")
    ap.add_argument("--regenerate", action="store_true", help="regenerate quantum/data/dev_claims.json")
    ap.add_argument("--verify-pairs", type=int, default=6, help="kernel entries to cross-check with the overlap circuit")
    args = ap.parse_args()

    data_path = HERE / "data" / "dev_claims.json"
    out = HERE / "results"
    out.mkdir(exist_ok=True)

    # 1. Data --------------------------------------------------------------------------------
    if args.regenerate or not data_path.exists():
        save_dev_dataset(generate_dev_dataset(seed=args.seed), data_path)
    dev_rows = load_dev_dataset(data_path)
    seed_rows = load_seed_claims(ROOT / "seed_sa_data.sql")

    ref_rows = [r for r in dev_rows if not r["synthetic_anomaly"]]
    anom_rows = [r for r in dev_rows if r["synthetic_anomaly"]]

    # 2. Features (prior_claim_count is computed within the population being scored) ----------
    dev_ids, X_dev = extract_features(to_records(dev_rows))
    is_ref = np.array([not r["synthetic_anomaly"] for r in dev_rows])
    seed_ids, X_seed = extract_features(to_records(seed_rows)) if seed_rows else ([], np.empty((0, N_FEATURES)))

    # 3. Preprocessing fitted on the reference population only --------------------------------
    pre = Preprocessor().fit(X_dev[is_ref])
    S_dev = pre.transform(X_dev)
    S_seed = pre.transform(X_seed) if len(seed_ids) else np.empty((0, N_FEATURES))
    S_ref = S_dev[is_ref]

    # 4. Classical baseline -------------------------------------------------------------------
    t0 = time.perf_counter()
    clf = ClassicalOneClass(nu=args.nu).fit(S_ref)
    raw_c_ref = clf.raw_scores(S_ref)
    raw_c_dev = clf.raw_scores(S_dev)
    raw_c_seed = clf.raw_scores(S_seed) if len(seed_ids) else np.array([])
    t_classical = time.perf_counter() - t0

    # 5. Quantum kernel -----------------------------------------------------------------------
    fmap = QuantumFeatureMap(n_qubits=N_FEATURES, reps=args.reps)
    t0 = time.perf_counter()
    states_dev = fmap.statevectors(Preprocessor.to_angles(S_dev))
    states_seed = fmap.statevectors(Preprocessor.to_angles(S_seed)) if len(seed_ids) else None
    t_states = time.perf_counter() - t0
    states_ref = states_dev[is_ref]

    t0 = time.perf_counter()
    K_ref = fmap.kernel_from_states(states_ref)
    K_dev_ref = fmap.kernel_from_states(states_dev, states_ref)
    K_seed_ref = fmap.kernel_from_states(states_seed, states_ref) if states_seed is not None else None
    t_kernel = time.perf_counter() - t0
    kernel_checks = validate_kernel(K_ref)

    # Cross-check a few statevector kernel entries against the adjoint-overlap circuit.
    rng = np.random.default_rng(0)
    angles_ref = Preprocessor.to_angles(S_ref)
    max_diff = 0.0
    for _ in range(args.verify_pairs):
        i, j = rng.integers(0, len(angles_ref), size=2)
        circuit_val = fmap.kernel_entry_circuit(angles_ref[i], angles_ref[j])
        max_diff = max(max_diff, abs(circuit_val - K_ref[i, j]))

    # 6. Quantum-kernel one-class model -------------------------------------------------------
    t0 = time.perf_counter()
    qoc = QuantumOneClass(nu=args.nu).fit(K_ref)
    raw_q_ref = qoc.raw_scores(K_ref)
    raw_q_dev = qoc.raw_scores(K_dev_ref)
    raw_q_seed = qoc.raw_scores(K_seed_ref) if K_seed_ref is not None else np.array([])
    t_quantum_fit = time.perf_counter() - t0

    # 7. Scores -> reference percentiles in [0, 1] -------------------------------------------
    c_dev = percentile_scores(raw_c_ref, raw_c_dev)
    q_dev = percentile_scores(raw_q_ref, raw_q_dev)
    c_seed = percentile_scores(raw_c_ref, raw_c_seed) if len(seed_ids) else np.array([])
    q_seed = percentile_scores(raw_q_ref, raw_q_seed) if len(seed_ids) else np.array([])

    def features_of(X_row, S_row) -> dict:
        return {
            name: {"raw": (None if np.isnan(X_row[k]) else round(float(X_row[k]), 3)), "scaled": round(float(S_row[k]), 4)}
            for k, name in enumerate(FEATURE_NAMES)
        }

    signals = []
    for k, cid in enumerate(dev_ids):
        signals.append(
            build_signal(cid, c_dev[k], q_dev[k], features_of(X_dev[k], S_dev[k]), MODEL_VERSION,
                         synthetic=True, synthetic_anomaly=bool(dev_rows[k]["synthetic_anomaly"]))
        )
    for k, cid in enumerate(seed_ids):
        signals.append(build_signal(cid, c_seed[k], q_seed[k], features_of(X_seed[k], S_seed[k]), MODEL_VERSION))

    # 8. Comparison metrics -------------------------------------------------------------------
    n_anom = int((~is_ref).sum())
    top_c = set(np.argsort(-c_dev)[:n_anom])
    top_q = set(np.argsort(-q_dev)[:n_anom])
    anom_idx = set(np.where(~is_ref)[0])
    by_recipe = {}
    for recipe in ANOMALY_RECIPES:
        idx = [k for k, r in enumerate(dev_rows) if r.get("anomaly_recipe") == recipe]
        if idx:
            by_recipe[recipe] = {
                "n": len(idx),
                "classical_mean": round(float(c_dev[idx].mean()), 3),
                "quantum_mean": round(float(q_dev[idx].mean()), 3),
                "classical_flagged_unusual_or_higher": int((c_dev[idx] >= 0.80).sum()),
                "quantum_flagged_unusual_or_higher": int((q_dev[idx] >= 0.80).sum()),
            }
    metrics = {
        "n_reference_synthetic_normal": int(is_ref.sum()),
        "n_synthetic_anomalies": n_anom,
        "n_seed_demo_claims": len(seed_ids),
        "spearman_rank_correlation_classical_vs_quantum": round(spearman(raw_c_dev, raw_q_dev), 4),
        "top_k_overlap_fraction": round(len(top_c & top_q) / max(n_anom, 1), 4),
        "synthetic_anomalies_in_classical_top_k": len(top_c & anom_idx),
        "synthetic_anomalies_in_quantum_top_k": len(top_q & anom_idx),
        "reference_score_mean_classical": round(float(c_dev[is_ref].mean()), 4),
        "reference_score_mean_quantum": round(float(q_dev[is_ref].mean()), 4),
        "anomaly_score_mean_classical": round(float(c_dev[~is_ref].mean()), 4),
        "anomaly_score_mean_quantum": round(float(q_dev[~is_ref].mean()), 4),
        "by_recipe": by_recipe,
        "kernel_checks": kernel_checks,
        "kernel_statevector_vs_circuit_max_abs_diff": round(max_diff, 10),
        "runtime_seconds": {
            "classical_fit_and_score": round(t_classical, 4),
            "quantum_statevectors": round(t_states, 4),
            "quantum_kernel_matrices": round(t_kernel, 4),
            "quantum_one_class_fit_and_score": round(t_quantum_fit, 4),
        },
        "circuit_evaluations_statevector_path": int(len(dev_ids) + len(seed_ids)),
        "circuit_evaluations_if_pairwise_on_hardware": int(len(S_ref) * (len(S_ref) - 1) // 2 + len(S_dev) * len(S_ref)),
    }

    result = {
        "model_version": MODEL_VERSION,
        "feature_version": FEATURE_VERSION,
        "kernel_version": KERNEL_VERSION,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "execution": "simulator",
        "hardware_used": False,
        "environment": {"python": platform.python_version(), "platform": platform.platform()},
        "features": list(FEATURE_NAMES),
        "preprocessing": pre.describe(),
        "classical_baseline": {"model": "sklearn OneClassSVM", "kernel": "rbf", "gamma": "scale", "nu": args.nu},
        "quantum_model": {**fmap.describe(), "one_class": "sklearn OneClassSVM(kernel='precomputed')", "nu": args.nu},
        "score_definition": "percentile of the raw one-class score within the synthetic reference population; "
        "bands NORMAL < 0.80 <= UNUSUAL < 0.95 <= HIGH_ANOMALY (screening heuristic, not a fraud threshold)",
        "metrics": metrics,
        "signals": [s.to_dict() for s in signals],
    }
    (out / "results.json").write_text(json.dumps(result, indent=1), encoding="utf8")

    # 9. Markdown table ------------------------------------------------------------------------
    lines = [
        f"# Phase 4 experiment results ({MODEL_VERSION})",
        "",
        f"Generated {result['generated_at']} on a local statevector SIMULATOR (PennyLane default.qubit). "
        "No quantum hardware was used. All `dev_claim_*` rows are SYNTHETIC development data; rows marked "
        "`synthetic anomaly` were generated by a named recipe and are not fraud cases.",
        "",
        "## Summary",
        "",
        "| Metric | Value |",
        "|---|---|",
        f"| Reference population (synthetic normal) | {metrics['n_reference_synthetic_normal']} |",
        f"| Synthetic anomalies | {metrics['n_synthetic_anomalies']} |",
        f"| Seed demo claims scored (real schema) | {metrics['n_seed_demo_claims']} |",
        f"| Qubits / features | {N_FEATURES} / {N_FEATURES} |",
        f"| Spearman rank correlation, classical vs quantum raw scores | {metrics['spearman_rank_correlation_classical_vs_quantum']} |",
        f"| Top-{n_anom} overlap between the two models | {metrics['top_k_overlap_fraction']} |",
        f"| Synthetic anomalies inside classical top-{n_anom} | {metrics['synthetic_anomalies_in_classical_top_k']} / {n_anom} |",
        f"| Synthetic anomalies inside quantum top-{n_anom} | {metrics['synthetic_anomalies_in_quantum_top_k']} / {n_anom} |",
        f"| Mean score, reference rows (classical / quantum) | {metrics['reference_score_mean_classical']} / {metrics['reference_score_mean_quantum']} |",
        f"| Mean score, synthetic anomalies (classical / quantum) | {metrics['anomaly_score_mean_classical']} / {metrics['anomaly_score_mean_quantum']} |",
        f"| Kernel valid (symmetric, unit diagonal, PSD) | {kernel_checks['valid']} (min eigenvalue {kernel_checks['min_eigenvalue']:.2e}) |",
        f"| Statevector vs overlap-circuit kernel entries, max abs diff | {metrics['kernel_statevector_vs_circuit_max_abs_diff']:.2e} |",
        f"| Runtime: classical fit+score | {metrics['runtime_seconds']['classical_fit_and_score']} s |",
        f"| Runtime: quantum statevectors + kernels + fit | {metrics['runtime_seconds']['quantum_statevectors'] + metrics['runtime_seconds']['quantum_kernel_matrices'] + metrics['runtime_seconds']['quantum_one_class_fit_and_score']:.4f} s |",
        f"| Circuit evaluations (statevector path) | {metrics['circuit_evaluations_statevector_path']} |",
        f"| Circuit evaluations if every kernel entry ran on hardware | {metrics['circuit_evaluations_if_pairwise_on_hardware']} |",
        "",
        "## By synthetic anomaly recipe",
        "",
        "| Recipe | n | Classical mean | Quantum mean | Classical >= UNUSUAL | Quantum >= UNUSUAL |",
        "|---|---|---|---|---|---|",
    ]
    for r, m in by_recipe.items():
        lines.append(f"| {r} | {m['n']} | {m['classical_mean']} | {m['quantum_mean']} | {m['classical_flagged_unusual_or_higher']} | {m['quantum_flagged_unusual_or_higher']} |")
    lines += ["", "## Synthetic anomalies and seed demo claims", "", "| CLAIM | KIND | CLASSICAL | QUANTUM | INTERPRETATION (quantum) |", "|---|---|---|---|---|"]
    for s in signals:
        if s.synthetic and not s.synthetic_anomaly:
            continue
        kind = "SYNTHETIC ANOMALY" if s.synthetic_anomaly else ("synthetic normal" if s.synthetic else "seed demo claim")
        lines.append(f"| {s.claim_id} | {kind} | {s.classical_anomaly:.2f} | {s.quantum_anomaly:.2f} | {s.interpretation} |")
    lines += ["", "## Reference population (first 15 of the synthetic normal rows)", "", "| CLAIM | CLASSICAL | QUANTUM | INTERPRETATION (quantum) |", "|---|---|---|---|"]
    for s in [s for s in signals if s.synthetic and not s.synthetic_anomaly][:15]:
        lines.append(f"| {s.claim_id} | {s.classical_anomaly:.2f} | {s.quantum_anomaly:.2f} | {s.interpretation} |")
    lines += ["", "## Interpretation text shown to assessors", ""]
    for k, v in EXPLANATIONS.items():
        lines.append(f"- **{k}**: {v}")
    (out / "results.md").write_text("\n".join(lines) + "\n", encoding="utf8")

    # 10. SQL for the Worker's screening_signals table (server-side import only) --------------
    computed_at = result["generated_at"]
    sql = [
        "-- Generated by quantum/experiment.py. Screening signals for claims that exist in the local D1 seed.",
        "-- Import (local only): npm run signals:import:local",
        "-- SIMULATOR results. The Worker never writes this table; no API route accepts these values.",
    ]
    for s in signals:
        if s.synthetic:
            continue
        sql.append(
            "INSERT OR REPLACE INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, "
            f"interpretation, execution, feature_snapshot, computed_at, imported_at) VALUES ({sql_str(s.claim_id)}, {sql_str(MODEL_VERSION)}, "
            f"{s.classical_anomaly}, {s.quantum_anomaly}, {sql_str(s.interpretation)}, 'simulator', "
            f"{sql_str(json.dumps({**s.features, '_feature_version': FEATURE_VERSION, '_kernel_version': KERNEL_VERSION}, separators=(',', ':')))}, "
            f"{sql_str(computed_at)}, strftime('%Y-%m-%dT%H:%M:%SZ','now'));"
        )
    (out / "screening_signals.sql").write_text("\n".join(sql) + "\n", encoding="utf8")

    # Two clearly-labelled demo claims (one low, one high) for DEMO 1 / DEMO 2, in stage Verified so
    # an ASSESSOR of ins_discovery can call POST /screen on them. Their content (category, narrative,
    # dates) is taken from two synthetic rows, but their SCORES are computed from their own features as
    # they will exist in the local D1 database (claims of user123 alongside the seed claims), through the
    # same fitted preprocessor and both models. This file is for the LOCAL demo database only.
    normal_pick = min((s for s in signals if s.synthetic and not s.synthetic_anomaly), key=lambda s: s.quantum_anomaly)
    high_pick = max((s for s in signals if s.synthetic_anomaly), key=lambda s: s.quantum_anomaly)
    demo_rows = []
    for demo_id, src in (("claim_demo_normal", normal_pick), ("claim_demo_unusual", high_pick)):
        row = dict(next(r for r in dev_rows if r["id"] == src.claim_id))
        row.update(id=demo_id, user_id="user123", policy_id="pol_disc_001", tenant_id="ins_discovery",
                   stage="Verified", status="Pending", synthetic=True, synthetic_anomaly=None, _source=src.claim_id)
        demo_rows.append(row)
    population = seed_rows + demo_rows
    pop_ids, X_pop = extract_features(to_records(population))
    S_pop = pre.transform(X_pop)
    raw_c_pop = clf.raw_scores(S_pop)
    K_pop_ref = fmap.kernel_from_states(fmap.statevectors(Preprocessor.to_angles(S_pop)), states_ref)
    raw_q_pop = qoc.raw_scores(K_pop_ref)
    c_pop = percentile_scores(raw_c_ref, raw_c_pop)
    q_pop = percentile_scores(raw_q_ref, raw_q_pop)
    demo_signals = {}
    for k, cid in enumerate(pop_ids):
        if cid.startswith("claim_demo_"):
            demo_signals[cid] = build_signal(cid, c_pop[k], q_pop[k], features_of(X_pop[k], S_pop[k]), MODEL_VERSION, synthetic=True)
    result["demo_claims"] = {
        cid: {"classical_anomaly": sig.classical_anomaly, "quantum_anomaly": sig.quantum_anomaly,
              "interpretation": sig.interpretation, "content_source": next(r["_source"] for r in demo_rows if r["id"] == cid)}
        for cid, sig in demo_signals.items()
    }
    (out / "results.json").write_text(json.dumps(result, indent=1), encoding="utf8")

    demo = [
        "-- Generated by quantum/experiment.py. LOCAL DEMO ONLY: two synthetic claims for user123 on pol_disc_001",
        "-- (tenant ins_discovery), stage Verified, plus their SIMULATOR screening signals, scored from the claims' own",
        "-- features (content copied from synthetic rows, see _source in feature_snapshot).",
        "-- Import (local only): npm run demo:quantum:local",
    ]
    for row in demo_rows:
        sig = demo_signals[row["id"]]
        demo.append(
            "INSERT OR REPLACE INTO claims (id, user_id, policy_id, tenant_id, stage, status, category, cause_of_loss, incident_date, created_at, updated_at) VALUES ("
            f"'{row['id']}', 'user123', 'pol_disc_001', 'ins_discovery', 'Verified', 'Pending', {sql_str(row['category'])}, "
            f"{sql_str(row['cause_of_loss'])}, {sql_str(row['incident_date'])}, {sql_str(row['created_at'])}, {sql_str(row['updated_at'])});"
        )
        demo.append(
            "INSERT OR REPLACE INTO screening_signals (claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, feature_snapshot, computed_at, imported_at) VALUES ("
            f"'{row['id']}', {sql_str(MODEL_VERSION)}, {sig.classical_anomaly}, {sig.quantum_anomaly}, {sql_str(sig.interpretation)}, 'simulator', "
            f"{sql_str(json.dumps({**sig.features, '_source': row['_source'], '_synthetic': True, '_feature_version': FEATURE_VERSION, '_kernel_version': KERNEL_VERSION}, separators=(',', ':')))}, "
            f"{sql_str(computed_at)}, strftime('%Y-%m-%dT%H:%M:%SZ','now'));"
        )
    (out / "demo_claims.sql").write_text("\n".join(demo) + "\n", encoding="utf8")

    print((out / "results.md").read_text(encoding="utf8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
