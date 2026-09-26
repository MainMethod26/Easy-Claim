"""One-class model on a precomputed quantum kernel, score calibration and interpretation."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Optional

import numpy as np
from sklearn.svm import OneClassSVM

# Anomaly score = percentile of the raw one-class score within the REFERENCE population.
# Bands are a screening heuristic, not a fraud threshold (see PHASE_04_REPORT.md).
BANDS: tuple[tuple[float, str], ...] = ((0.95, "HIGH_ANOMALY"), (0.80, "UNUSUAL"), (0.0, "NORMAL"))

EXPLANATIONS: dict[str, str] = {
    "NORMAL": "The claim is structurally similar to the reference claim population.",
    "UNUSUAL": "The claim is somewhat unusual compared with the reference claim population.",
    "HIGH_ANOMALY": "The claim is structurally unusual compared with the reference claim population. "
    "Suggest human review. This is a screening signal, not a fraud finding.",
}


class QuantumOneClass:
    """OneClassSVM trained on a precomputed (quantum) kernel matrix."""

    def __init__(self, nu: float = 0.1) -> None:
        self.model = OneClassSVM(kernel="precomputed", nu=nu)

    def fit(self, K_ref: np.ndarray) -> "QuantumOneClass":
        self.model.fit(K_ref)
        return self

    def raw_scores(self, K_test_ref: np.ndarray) -> np.ndarray:
        """K_test_ref: kernel between test rows and the reference rows used in fit()."""
        return -self.model.decision_function(K_test_ref)


def percentile_scores(raw_ref: np.ndarray, raw: np.ndarray) -> np.ndarray:
    """Empirical CDF of `raw` against the reference raw scores -> anomaly score in [0, 1]."""
    ref = np.sort(np.asarray(raw_ref, dtype=float))
    return np.searchsorted(ref, np.asarray(raw, dtype=float), side="right") / ref.size


def interpret(score: float) -> str:
    if np.isnan(score) or not (0.0 <= score <= 1.0):
        raise ValueError(f"anomaly score must be in [0, 1], got {score}")
    for lower, label in BANDS:
        if score >= lower:
            return label
    return "NORMAL"


@dataclass(frozen=True)
class ScreeningSignal:
    """The ONLY output of the quantum track. It carries scores and text; it has no stage,
    status, tenant, owner, evidence or payout fields, so it cannot express a state change."""

    claim_id: str
    classical_anomaly: float
    quantum_anomaly: float
    interpretation: str
    model_version: str
    execution: str  # 'simulator' | 'hardware'
    features: dict
    synthetic: bool = False
    synthetic_anomaly: Optional[bool] = None

    def to_dict(self) -> dict:
        return asdict(self)


def build_signal(
    claim_id: str,
    classical: float,
    quantum: float,
    features: dict,
    model_version: str,
    execution: str = "simulator",
    synthetic: bool = False,
    synthetic_anomaly: Optional[bool] = None,
) -> ScreeningSignal:
    if execution not in ("simulator", "hardware"):
        raise ValueError("execution must be 'simulator' or 'hardware'")
    return ScreeningSignal(
        claim_id=claim_id,
        classical_anomaly=round(float(classical), 4),
        quantum_anomaly=round(float(quantum), 4),
        interpretation=interpret(float(quantum)),
        model_version=model_version,
        execution=execution,
        features=features,
        synthetic=synthetic,
        synthetic_anomaly=synthetic_anomaly,
    )
