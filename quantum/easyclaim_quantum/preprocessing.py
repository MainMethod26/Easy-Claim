"""Reproducible preprocessing shared by the classical baseline and the quantum kernel.

impute (reference medians) -> log1p on counts/durations -> min-max on the reference range
-> soft clip into [0, 1] -> for the quantum feature map only: multiply by pi (angles in [0, pi]).

Soft clip: the reference [min, max] maps to [0, IN_RANGE_TOP]; values above the reference
maximum are compressed into (IN_RANGE_TOP, 1) with 1 - exp(-(s - 1)), so a value far outside
the reference range still ranks above one at the edge instead of being flattened onto it.
The exact same scaled matrix feeds both models, which is what makes the comparison fair.
"""
from __future__ import annotations

import numpy as np

from .features import LOG_COLUMNS, N_FEATURES

IN_RANGE_TOP = 0.75


class Preprocessor:
    def __init__(self) -> None:
        self.medians_: np.ndarray | None = None
        self.mins_: np.ndarray | None = None
        self.maxs_: np.ndarray | None = None

    @staticmethod
    def _check(X: np.ndarray) -> np.ndarray:
        X = np.asarray(X, dtype=float)
        if X.ndim != 2 or X.shape[1] != N_FEATURES:
            raise ValueError(f"expected shape (n, {N_FEATURES}), got {X.shape}")
        if X.shape[0] == 0:
            raise ValueError("empty feature matrix")
        return X

    def _impute_log(self, X: np.ndarray) -> np.ndarray:
        assert self.medians_ is not None
        X = X.copy()
        nan = np.isnan(X)
        X[nan] = np.take(self.medians_, np.where(nan)[1])
        X[:, LOG_COLUMNS] = np.log1p(np.clip(X[:, LOG_COLUMNS], 0, None))
        return X

    def fit(self, X_ref: np.ndarray) -> "Preprocessor":
        X_ref = self._check(X_ref)
        medians = np.nanmedian(X_ref, axis=0)
        # A column that is entirely missing in the reference set gets 0 (documented limitation).
        medians = np.where(np.isnan(medians), 0.0, medians)
        self.medians_ = medians
        Z = self._impute_log(X_ref)
        self.mins_ = Z.min(axis=0)
        self.maxs_ = Z.max(axis=0)
        return self

    def transform(self, X: np.ndarray) -> np.ndarray:
        if self.medians_ is None or self.mins_ is None or self.maxs_ is None:
            raise RuntimeError("Preprocessor.fit must be called first")
        Z = self._impute_log(self._check(X))
        span = self.maxs_ - self.mins_
        safe_span = np.where(span > 0, span, 1.0)
        s = np.where(span > 0, (Z - self.mins_) / safe_span, 0.0)
        s = np.clip(s, 0.0, None)
        above = s > 1.0
        out = np.where(above, IN_RANGE_TOP + (1.0 - IN_RANGE_TOP) * (1.0 - np.exp(-(s - 1.0))), s * IN_RANGE_TOP)
        return np.clip(out, 0.0, 1.0)

    def fit_transform(self, X_ref: np.ndarray) -> np.ndarray:
        return self.fit(X_ref).transform(X_ref)

    @staticmethod
    def to_angles(X_scaled: np.ndarray) -> np.ndarray:
        """Map [0, 1] features to rotation angles in [0, pi] for the quantum feature map."""
        return np.asarray(X_scaled, dtype=float) * np.pi

    def describe(self) -> dict:
        assert self.medians_ is not None and self.mins_ is not None and self.maxs_ is not None
        return {
            "impute_medians": self.medians_.round(4).tolist(),
            "log1p_columns": list(LOG_COLUMNS),
            "scale_min": self.mins_.round(4).tolist(),
            "scale_max": self.maxs_.round(4).tolist(),
            "in_range_top": IN_RANGE_TOP,
            "above_range": "IN_RANGE_TOP + (1 - IN_RANGE_TOP) * (1 - exp(-(s - 1)))",
        }
