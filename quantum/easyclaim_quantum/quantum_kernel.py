"""Quantum feature map and fidelity kernel (PennyLane, default.qubit statevector simulator).

One qubit per feature (5 features -> 5 qubits). Feature map U(x), repeated `reps` times:
    H on every wire, RZ(x_i) on wire i                                   (first-order encoding)
    for neighbouring wires (i, i+1): CNOT, RZ(x_i * x_{i+1} / pi), CNOT  (second-order)
with x_i in [0, pi]. The kernel is the state fidelity k(x, y) = |<phi(y)|phi(x)>|^2.

Two evaluation paths are provided and tested against each other:
  * statevector path: simulate |phi(x)> once per claim and take |<.|.>|^2 (fast, exact)
  * circuit path: run U(x) then U(y)^dagger and read the probability of |0...0>, which is
    how the same quantity would be estimated on hardware with shots.
The kernel is a similarity function only. It is not itself an anomaly or fraud detector.
"""
from __future__ import annotations

import numpy as np
import pennylane as qml


class QuantumFeatureMap:
    def __init__(self, n_qubits: int, reps: int = 2) -> None:
        if n_qubits < 1 or n_qubits > 12:
            raise ValueError("n_qubits must be between 1 and 12 for a reliable local simulation")
        if reps < 1:
            raise ValueError("reps must be >= 1")
        self.n_qubits = n_qubits
        self.reps = reps
        self.device = qml.device("default.qubit", wires=n_qubits)

        @qml.qnode(self.device)
        def _state(x):
            self.apply(x)
            return qml.state()

        @qml.qnode(self.device)
        def _overlap_probs(x, y):
            self.apply(x)
            qml.adjoint(self.apply)(y)
            return qml.probs(wires=range(self.n_qubits))

        self._state = _state
        self._overlap_probs = _overlap_probs

    def apply(self, x) -> None:
        """Feature-map unitary U(x); x has one angle in [0, pi] per qubit."""
        n = self.n_qubits
        for _ in range(self.reps):
            for i in range(n):
                qml.Hadamard(wires=i)
                qml.RZ(x[i], wires=i)
            for i in range(n - 1):
                qml.CNOT(wires=[i, i + 1])
                qml.RZ(x[i] * x[i + 1] / np.pi, wires=i + 1)
                qml.CNOT(wires=[i, i + 1])

    def _check_angles(self, X: np.ndarray) -> np.ndarray:
        X = np.asarray(X, dtype=float)
        if X.ndim != 2 or X.shape[1] != self.n_qubits:
            raise ValueError(f"expected angles of shape (n, {self.n_qubits}), got {X.shape}")
        if np.isnan(X).any():
            raise ValueError("angles contain NaN; run the Preprocessor first")
        if (X < -1e-9).any() or (X > np.pi + 1e-9).any():
            raise ValueError("angles must lie in [0, pi]")
        return X

    def statevectors(self, X_angles: np.ndarray) -> np.ndarray:
        X = self._check_angles(X_angles)
        return np.stack([np.asarray(self._state(x)) for x in X])

    @staticmethod
    def kernel_from_states(A: np.ndarray, B: np.ndarray | None = None) -> np.ndarray:
        """Fidelity kernel between rows of A and rows of B (defaults to A)."""
        B = A if B is None else B
        return np.abs(A.conj() @ B.T) ** 2

    def kernel_entry_circuit(self, x: np.ndarray, y: np.ndarray) -> float:
        """k(x, y) via the adjoint-overlap circuit (what a shot-based backend would run)."""
        probs = self._overlap_probs(np.asarray(x, dtype=float), np.asarray(y, dtype=float))
        return float(probs[0])

    def describe(self) -> dict:
        return {
            "framework": "PennyLane",
            "device": "default.qubit (statevector simulator)",
            "n_qubits": self.n_qubits,
            "reps": self.reps,
            "feature_map": "H + RZ(x_i) per wire, then CNOT-RZ(x_i*x_j/pi)-CNOT on neighbouring wires, repeated",
            "kernel": "state fidelity |<phi(y)|phi(x)>|^2",
        }


def validate_kernel(K: np.ndarray, atol: float = 1e-8) -> dict:
    """Check the kernel matrix is square, symmetric, unit-diagonal, in [0, 1] and PSD."""
    K = np.asarray(K, dtype=float)
    if K.ndim != 2 or K.shape[0] != K.shape[1]:
        raise ValueError(f"kernel must be square, got {K.shape}")
    checks: dict = {
        "square": True,
        "symmetric": bool(np.allclose(K, K.T, atol=1e-7)),
        "unit_diagonal": bool(np.allclose(np.diag(K), 1.0, atol=1e-7)),
        "in_unit_interval": bool((K >= -atol).all() and (K <= 1 + 1e-7).all()),
    }
    min_eig = float(np.linalg.eigvalsh((K + K.T) / 2).min())
    checks["min_eigenvalue"] = min_eig
    checks["positive_semidefinite"] = bool(min_eig >= -1e-6)
    checks["valid"] = all(v for v in checks.values() if isinstance(v, bool))
    if not checks["valid"]:
        raise ValueError(f"invalid kernel matrix: {checks}")
    return checks
