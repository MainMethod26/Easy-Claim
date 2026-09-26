"""Classical baseline: one-class SVM with an RBF kernel on the identical preprocessed features."""
from __future__ import annotations

import numpy as np
from sklearn.svm import OneClassSVM


class ClassicalOneClass:
    def __init__(self, nu: float = 0.1, gamma: str | float = "scale") -> None:
        self.model = OneClassSVM(kernel="rbf", nu=nu, gamma=gamma)

    def fit(self, X_ref_scaled: np.ndarray) -> "ClassicalOneClass":
        self.model.fit(X_ref_scaled)
        return self

    def raw_scores(self, X_scaled: np.ndarray) -> np.ndarray:
        """Higher = more anomalous (negated signed distance to the one-class boundary)."""
        return -self.model.decision_function(X_scaled)
