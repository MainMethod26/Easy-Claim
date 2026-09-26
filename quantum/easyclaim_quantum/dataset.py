"""Development dataset for the Phase 4 experiment.

EasyClaim has three seeded demo claims and no labelled fraud data, so the experiment runs on a
SYNTHETIC development dataset that mirrors the `claims` table schema exactly. Every row carries
`synthetic: true`; rows produced by an anomaly recipe carry `synthetic_anomaly: true` and the
recipe name. These are NOT real claims and NOT fraud cases. They exist only to exercise the
pipeline and to check whether the two one-class models rank clearly-unusual structures highly.
"""
from __future__ import annotations

import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np

from .features import CATEGORIES, ClaimRecord

TENANTS = ("ins_discovery", "ins_sanlam", "ins_outsurance", "ins_momentum", "ins_oldmutual")

# Small neutral vocabulary so cause_of_loss has a realistic word count without inventing a story.
_WORDS = (
    "the vehicle was damaged in a collision at the intersection and towed to the panel beater "
    "hospital admission for treatment following symptoms reported to the general practitioner "
    "burst geyser flooded the ceiling and kitchen units require replacement quotes attached "
    "mobile phone stolen from bag at the taxi rank police case number provided "
    "policyholder passed away certificate issued by the department of home affairs"
).split()

ANOMALY_RECIPES: dict[str, str] = {
    "late_report": "incident reported 180-400 days after it happened (reference: median about a week)",
    "serial_claimant": "eight claims from one user id in the population (reference: median 2, maximum 4 prior claims)",
    "night_minimal_narrative": "created at 02:00-04:00 with a 1-3 word narrative (reference: daytime, ~25 words)",
}


def _narrative(rng: np.random.Generator, n_words: int) -> str:
    n_words = max(1, int(n_words))
    return " ".join(rng.choice(_WORDS, size=n_words))


def _row(
    rng: np.random.Generator,
    idx: int,
    user_id: str,
    category: str,
    days_to_report: float,
    hour: int,
    n_words: int,
    base: datetime,
    anomaly: str | None,
) -> dict:
    created = base + timedelta(days=int(rng.integers(0, 120)), hours=int(hour), minutes=int(rng.integers(0, 60)))
    incident = (created - timedelta(days=float(days_to_report))).date()
    tenant = TENANTS[int(rng.integers(0, len(TENANTS)))]
    return {
        "id": f"dev_claim_{idx:04d}",
        "user_id": user_id,
        "policy_id": f"pol_dev_{user_id[-4:]}",
        "tenant_id": tenant,
        "stage": "Screening",
        "status": "Pending",
        "category": category,
        "cause_of_loss": _narrative(rng, n_words),
        "incident_date": incident.isoformat(),
        "created_at": created.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "updated_at": created.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "synthetic": True,
        "synthetic_anomaly": anomaly is not None,
        "anomaly_recipe": anomaly,
    }


def generate_dev_dataset(n_normal: int = 120, n_anomalies: int = 12, seed: int = 4) -> list[dict]:
    """Deterministic synthetic development dataset (same seed -> identical rows)."""
    rng = np.random.default_rng(seed)
    base = datetime(2026, 5, 1, tzinfo=timezone.utc)
    rows: list[dict] = []
    idx = 0

    # Reference ("normal") population: ~60 users holding 1-3 claims each, daytime submissions,
    # incident reported within days, ~25-word narrative. Category mix loosely follows the seed.
    users = [f"dev_user_{i:04d}" for i in range(60)]
    cat_p = np.array([0.30, 0.30, 0.10, 0.20, 0.10])
    while len(rows) < n_normal:
        user = users[int(rng.integers(0, len(users)))]
        category = str(rng.choice(CATEGORIES, p=cat_p))
        days = float(np.clip(rng.lognormal(mean=np.log(6), sigma=0.8), 0, 60))
        hour = int(np.clip(rng.normal(13, 3.5), 7, 21))
        words = int(np.clip(rng.normal(25, 8), 8, 60))
        rows.append(_row(rng, idx, user, category, days, hour, words, base, None))
        idx += 1

    # Synthetic anomalies, spread over the three recipes (labelled, never presented as fraud).
    recipes = list(ANOMALY_RECIPES)
    per = n_anomalies // len(recipes)
    counts = {r: per for r in recipes}
    for r in recipes[: n_anomalies - per * len(recipes)]:
        counts[r] += 1

    for _ in range(counts["late_report"]):
        user = users[int(rng.integers(0, len(users)))]
        rows.append(_row(rng, idx, user, str(rng.choice(CATEGORIES)), float(rng.uniform(180, 400)),
                         int(rng.integers(8, 19)), int(rng.integers(15, 35)), base, "late_report"))
        idx += 1

    # serial_claimant: the anomaly is the user's claim count, so several rows share one user id.
    serial_user = "dev_user_serial"
    for _ in range(max(counts["serial_claimant"], 0)):
        rows.append(_row(rng, idx, serial_user, str(rng.choice(CATEGORIES)),
                         float(np.clip(rng.lognormal(mean=np.log(6), sigma=0.8), 0, 60)),
                         int(rng.integers(8, 19)), int(rng.integers(15, 35)), base, "serial_claimant"))
        idx += 1
    # top the serial user up to eight claims total so prior_claim_count is clearly out of range
    while sum(1 for r in rows if r["user_id"] == serial_user) < 8:
        rows.append(_row(rng, idx, serial_user, str(rng.choice(CATEGORIES)), 5.0, 12, 25, base, "serial_claimant"))
        idx += 1

    for _ in range(counts["night_minimal_narrative"]):
        user = users[int(rng.integers(0, len(users)))]
        rows.append(_row(rng, idx, user, str(rng.choice(CATEGORIES)), float(rng.uniform(0, 10)),
                         int(rng.integers(2, 5)), int(rng.integers(1, 4)), base, "night_minimal_narrative"))
        idx += 1

    return rows


def save_dev_dataset(rows: list[dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "_notice": "SYNTHETIC development data for the EasyClaim Phase 4 quantum experiment. "
        "Not real claims. Not fraud cases. Rows with synthetic_anomaly=true were generated by the "
        "named recipe so the pipeline has something clearly unusual to rank.",
        "recipes": ANOMALY_RECIPES,
        "claims": rows,
    }
    path.write_text(json.dumps(payload, indent=1), encoding="utf8")


def load_dev_dataset(path: Path) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf8"))
    rows = payload["claims"]
    if not all(r.get("synthetic") is True for r in rows):
        raise ValueError("development dataset rows must all be marked synthetic")
    return rows


_SEED_RE = re.compile(r"INSERT INTO claims \(([^)]*)\) VALUES\s*(.*?);", re.S | re.I)
_TUPLE_RE = re.compile(r"\(([^()]*)\)")


def load_seed_claims(seed_sql: Path) -> list[dict]:
    """Parse the three demo claims from seed_sa_data.sql (real schema, demo values)."""
    text = seed_sql.read_text(encoding="utf8")
    m = _SEED_RE.search(text)
    if not m:
        return []
    cols = [c.strip() for c in m.group(1).split(",")]
    rows = []
    for t in _TUPLE_RE.findall(m.group(2)):
        vals = [v.strip().strip("'") for v in t.split(",")]
        row = {c: (None if v.upper() == "NULL" else v) for c, v in zip(cols, vals)}
        row["synthetic"] = False
        row["synthetic_anomaly"] = None
        rows.append(row)
    return rows


def to_records(rows: list[dict]) -> list[ClaimRecord]:
    keep = set(ClaimRecord.__dataclass_fields__)  # type: ignore[attr-defined]
    return [ClaimRecord.from_dict({k: v for k, v in r.items() if k in keep}) for r in rows]
