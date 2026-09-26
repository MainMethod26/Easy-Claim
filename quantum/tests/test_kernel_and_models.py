import dataclasses

import numpy as np
import pytest

from easyclaim_quantum.classical import ClassicalOneClass
from easyclaim_quantum.features import N_FEATURES
from easyclaim_quantum.model import EXPLANATIONS, QuantumOneClass, ScreeningSignal, build_signal, interpret, percentile_scores
from easyclaim_quantum.preprocessing import Preprocessor
from easyclaim_quantum.quantum_kernel import QuantumFeatureMap, validate_kernel


@pytest.fixture(scope="module")
def data():
    rng = np.random.default_rng(7)
    X = rng.uniform(0, 1, size=(30, N_FEATURES))
    fmap = QuantumFeatureMap(n_qubits=N_FEATURES, reps=2)
    states = fmap.statevectors(Preprocessor.to_angles(X))
    K = fmap.kernel_from_states(states)
    return X, fmap, states, K


def test_kernel_matrix_is_valid(data):
    _, _, _, K = data
    checks = validate_kernel(K)
    assert checks["valid"] and checks["symmetric"] and checks["unit_diagonal"] and checks["positive_semidefinite"]


def test_statevector_kernel_matches_overlap_circuit(data):
    X, fmap, _, K = data
    A = Preprocessor.to_angles(X)
    for i, j in [(0, 1), (2, 9), (5, 5), (11, 3)]:
        assert abs(fmap.kernel_entry_circuit(A[i], A[j]) - K[i, j]) < 1e-9


def test_kernel_is_deterministic(data):
    X, fmap, states, K = data
    K2 = fmap.kernel_from_states(fmap.statevectors(Preprocessor.to_angles(X)))
    assert np.allclose(K, K2)


def test_feature_map_rejects_bad_angles():
    fmap = QuantumFeatureMap(n_qubits=N_FEATURES)
    with pytest.raises(ValueError):
        fmap.statevectors(np.full((2, N_FEATURES), np.nan))
    with pytest.raises(ValueError):
        fmap.statevectors(np.full((2, N_FEATURES), 4.0))
    with pytest.raises(ValueError):
        fmap.statevectors(np.zeros((2, N_FEATURES + 1)))
    with pytest.raises(ValueError):
        QuantumFeatureMap(n_qubits=0)


def test_validate_kernel_rejects_invalid():
    with pytest.raises(ValueError):
        validate_kernel(np.ones((2, 3)))
    bad = np.array([[1.0, 2.0], [2.0, 1.0]])  # not PSD, entries > 1
    with pytest.raises(ValueError):
        validate_kernel(bad)


def test_models_run_and_scores_are_bounded(data):
    X, fmap, states, K = data
    ref = slice(0, 20)
    clf = ClassicalOneClass(nu=0.1).fit(X[ref])
    raw_c_ref, raw_c = clf.raw_scores(X[ref]), clf.raw_scores(X)
    qoc = QuantumOneClass(nu=0.1).fit(K[ref, ref])
    raw_q_ref, raw_q = qoc.raw_scores(K[ref, ref]), qoc.raw_scores(K[:, ref])
    c = percentile_scores(raw_c_ref, raw_c)
    q = percentile_scores(raw_q_ref, raw_q)
    assert c.shape == q.shape == (30,)
    assert (0 <= c).all() and (c <= 1).all() and (0 <= q).all() and (q <= 1).all()


def test_scores_reproducible(data):
    X, _, _, K = data
    a = QuantumOneClass(nu=0.1).fit(K).raw_scores(K)
    b = QuantumOneClass(nu=0.1).fit(K).raw_scores(K)
    assert np.allclose(a, b)


def test_interpretation_bands():
    assert interpret(0.0) == "NORMAL"
    assert interpret(0.79) == "NORMAL"
    assert interpret(0.80) == "UNUSUAL"
    assert interpret(0.949) == "UNUSUAL"
    assert interpret(0.95) == "HIGH_ANOMALY"
    assert interpret(1.0) == "HIGH_ANOMALY"
    with pytest.raises(ValueError):
        interpret(1.2)
    assert set(EXPLANATIONS) == {"NORMAL", "UNUSUAL", "HIGH_ANOMALY"}
    for text in EXPLANATIONS.values():
        assert "fraud" not in text.lower().replace("not a fraud finding", "")


def test_signal_cannot_express_state_or_authorization_changes():
    s = build_signal("c1", 0.1, 0.97, {"f": 1}, "v1")
    names = {f.name for f in dataclasses.fields(ScreeningSignal)}
    forbidden = {"stage", "status", "tenant_id", "user_id", "role", "payout", "evidence", "decision", "approved"}
    assert names.isdisjoint(forbidden)
    assert s.interpretation == "HIGH_ANOMALY"
    with pytest.raises(dataclasses.FrozenInstanceError):
        s.claim_id = "other"  # type: ignore[misc]
    with pytest.raises(ValueError):
        build_signal("c1", 0.1, 0.5, {}, "v1", execution="production-qpu")
