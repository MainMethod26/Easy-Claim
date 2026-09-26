import json
import re
import subprocess
import sys
from pathlib import Path

from easyclaim_quantum.dataset import ANOMALY_RECIPES, generate_dev_dataset, load_seed_claims, to_records
from easyclaim_quantum.features import extract_features

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parent


def test_generator_is_deterministic_and_labelled():
    a = generate_dev_dataset(seed=4)
    b = generate_dev_dataset(seed=4)
    assert a == b
    assert all(r["synthetic"] is True for r in a)
    anomalies = [r for r in a if r["synthetic_anomaly"]]
    assert anomalies and all(r["anomaly_recipe"] in ANOMALY_RECIPES for r in anomalies)
    assert all(r["anomaly_recipe"] is None for r in a if not r["synthetic_anomaly"])
    ids, X = extract_features(to_records(a))
    assert len(ids) == len(a) and X.shape[1] == 5


def test_seed_claims_parse_with_real_schema():
    rows = load_seed_claims(ROOT / "seed_sa_data.sql")
    assert {r["id"] for r in rows} == {"claim_disc_101", "claim_sanlam_102", "claim_mom_103"}
    assert all(r["synthetic"] is False for r in rows)
    ids, X = extract_features(to_records(rows))  # missing dates/categories become NaN, not errors
    assert len(ids) == 3


def test_export_sql_only_touches_screening_signals(tmp_path):
    """The Worker-import file must never write claims, audit or any other table."""
    results = HERE / "results"
    if not (results / "screening_signals.sql").exists():
        subprocess.run([sys.executable, str(HERE / "experiment.py")], check=True, capture_output=True)
    sql = (results / "screening_signals.sql").read_text(encoding="utf8")
    statements = [s for s in sql.splitlines() if s and not s.startswith("--")]
    assert statements
    assert all(re.match(r"^INSERT OR REPLACE INTO screening_signals \(", s) for s in statements)
    assert "UPDATE" not in sql.upper().replace("INSERT OR REPLACE", "")
    payload = json.loads((results / "results.json").read_text(encoding="utf8"))
    assert payload["execution"] == "simulator" and payload["hardware_used"] is False
