"""Feature extraction from EasyClaim claim rows.

Only columns that exist in the `claims` table today are used (migrations 0001-0003):
id, user_id, policy_id, tenant_id, stage, status, category, cause_of_loss, incident_date,
created_at, updated_at. No claim amount, policy start date or evidence rows exist yet, so those
are documented as future features, not fabricated.
"""
from __future__ import annotations

from dataclasses import dataclass, fields
from datetime import date, datetime, timezone
from typing import Iterable, Optional, Sequence

import numpy as np

CATEGORIES: tuple[str, ...] = ("Medical", "Vehicle", "Life", "Property", "Other")

FEATURE_NAMES: tuple[str, ...] = (
    "days_to_report",        # created_at - incident_date, in days (missing if either is absent)
    "category_index",        # ordinal index into CATEGORIES (missing if category is NULL)
    "prior_claim_count",     # other claims by the same user_id in the population being scored
    "narrative_word_count",  # words in cause_of_loss (0 if NULL) - completeness proxy
    "submission_hour",       # hour of day (UTC) of created_at (missing if absent)
)
N_FEATURES = len(FEATURE_NAMES)

# Columns that are counts/durations and get log1p before scaling (see preprocessing.py).
LOG_COLUMNS: tuple[int, ...] = (0, 2, 3)


@dataclass(frozen=True)
class ClaimRecord:
    """A row of the claims table. Every field mirrors a real column; nothing is invented."""

    id: str
    user_id: Optional[str] = None
    policy_id: Optional[str] = None
    tenant_id: Optional[str] = None
    stage: Optional[str] = None
    status: Optional[str] = None
    category: Optional[str] = None
    cause_of_loss: Optional[str] = None
    incident_date: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

    @classmethod
    def from_dict(cls, row: dict) -> "ClaimRecord":
        if not isinstance(row, dict) or not isinstance(row.get("id"), str) or not row["id"]:
            raise ValueError("claim record must be a dict with a non-empty string 'id'")
        allowed = {f.name for f in fields(cls)}
        kwargs = {k: row.get(k) for k in allowed}
        for k, v in kwargs.items():
            if v is not None and not isinstance(v, str):
                raise ValueError(f"claim {row['id']}: field {k!r} must be a string or null, got {type(v).__name__}")
        return cls(**kwargs)


def _parse_date(value: Optional[str], field: str, claim_id: str) -> Optional[date]:
    if value is None or value == "":
        return None
    try:
        return date.fromisoformat(value[:10])
    except ValueError as e:
        raise ValueError(f"claim {claim_id}: {field} is not an ISO date: {value!r}") from e


def _parse_datetime(value: Optional[str], field: str, claim_id: str) -> Optional[datetime]:
    if value is None or value == "":
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as e:
        raise ValueError(f"claim {claim_id}: {field} is not an ISO datetime: {value!r}") from e
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _category_index(category: Optional[str], claim_id: str) -> float:
    if category is None or category == "":
        return np.nan
    if category not in CATEGORIES:
        raise ValueError(f"claim {claim_id}: unknown category {category!r}; allowed: {CATEGORIES}")
    return float(CATEGORIES.index(category))


def extract_features(claims: Sequence[ClaimRecord]) -> tuple[list[str], np.ndarray]:
    """Return (claim_ids, X) with X shape (n, N_FEATURES). Missing values are NaN.

    Raises ValueError on malformed input (bad dates, unknown category, duplicate ids). A
    negative days_to_report (incident after the claim was created) is treated as missing
    and left for the imputer; the API already rejects future incident dates.
    """
    ids = [c.id for c in claims]
    if len(set(ids)) != len(ids):
        raise ValueError("duplicate claim ids in input")

    user_counts: dict[str, int] = {}
    for c in claims:
        if c.user_id:
            user_counts[c.user_id] = user_counts.get(c.user_id, 0) + 1

    X = np.full((len(claims), N_FEATURES), np.nan, dtype=float)
    for i, c in enumerate(claims):
        incident = _parse_date(c.incident_date, "incident_date", c.id)
        created = _parse_datetime(c.created_at, "created_at", c.id)
        if incident is not None and created is not None:
            days = (created.date() - incident).days
            X[i, 0] = float(days) if days >= 0 else np.nan
        X[i, 1] = _category_index(c.category, c.id)
        X[i, 2] = float(user_counts.get(c.user_id, 1) - 1) if c.user_id else np.nan
        X[i, 3] = float(len(c.cause_of_loss.split())) if c.cause_of_loss else 0.0
        X[i, 4] = float(created.hour) if created is not None else np.nan
    return ids, X


def records_from_rows(rows: Iterable[dict]) -> list[ClaimRecord]:
    return [ClaimRecord.from_dict(r) for r in rows]
