import numpy as np
import pytest

from easyclaim_quantum.features import CATEGORIES, FEATURE_NAMES, N_FEATURES, ClaimRecord, extract_features
from easyclaim_quantum.preprocessing import Preprocessor


def rec(**kw):
    base = dict(id="c1", user_id="u1", category="Vehicle", cause_of_loss="car hit at corner", incident_date="2026-05-01", created_at="2026-05-04T10:15:00Z")
    base.update(kw)
    return ClaimRecord.from_dict(base)


def test_feature_names_match_width():
    assert len(FEATURE_NAMES) == N_FEATURES == 5


def test_extract_basic_values():
    ids, X = extract_features([rec()])
    assert ids == ["c1"]
    assert X.shape == (1, N_FEATURES)
    assert X[0, 0] == 3.0                      # days_to_report
    assert X[0, 1] == CATEGORIES.index("Vehicle")
    assert X[0, 2] == 0.0                      # no other claims by u1
    assert X[0, 3] == 4.0                      # four words
    assert X[0, 4] == 10.0                     # hour


def test_prior_claim_count_uses_population():
    ids, X = extract_features([rec(id="a", user_id="u1"), rec(id="b", user_id="u1"), rec(id="c", user_id="u2")])
    assert list(X[:, 2]) == [1.0, 1.0, 0.0]


def test_missing_values_become_nan_not_errors():
    _, X = extract_features([rec(incident_date=None, category=None, cause_of_loss=None, created_at=None)])
    assert np.isnan(X[0, 0]) and np.isnan(X[0, 1]) and np.isnan(X[0, 4])
    assert X[0, 3] == 0.0


def test_negative_days_treated_as_missing():
    _, X = extract_features([rec(incident_date="2026-06-01", created_at="2026-05-04T10:15:00Z")])
    assert np.isnan(X[0, 0])


@pytest.mark.parametrize("bad", [dict(category="Boat"), dict(incident_date="yesterday"), dict(created_at="not a time")])
def test_invalid_input_rejected(bad):
    with pytest.raises(ValueError):
        extract_features([rec(**bad)])


def test_non_string_field_and_missing_id_rejected():
    with pytest.raises(ValueError):
        ClaimRecord.from_dict({"id": "x", "category": 3})
    with pytest.raises(ValueError):
        ClaimRecord.from_dict({"category": "Vehicle"})


def test_duplicate_ids_rejected():
    with pytest.raises(ValueError):
        extract_features([rec(id="dup"), rec(id="dup")])


def test_preprocessor_output_bounded_and_nan_free():
    rng = np.random.default_rng(1)
    X = rng.uniform(0, 30, size=(40, N_FEATURES))
    X[3, 0] = np.nan
    X[7, 4] = np.nan
    pre = Preprocessor().fit(X)
    S = pre.transform(X)
    assert S.shape == X.shape
    assert not np.isnan(S).any()
    assert S.min() >= 0.0 and S.max() <= 1.0
    angles = Preprocessor.to_angles(S)
    assert angles.min() >= 0.0 and angles.max() <= np.pi


def test_preprocessor_constant_column_and_reproducibility():
    X = np.ones((10, N_FEATURES))
    X[:, 0] = np.arange(10)
    pre = Preprocessor().fit(X)
    S1 = pre.transform(X)
    S2 = Preprocessor().fit(X).transform(X)
    assert np.allclose(S1, S2)
    assert np.all(S1[:, 1] == 0.0)  # constant column maps to 0, no division by zero


def test_values_beyond_reference_range_keep_their_order():
    X = np.zeros((10, N_FEATURES))
    X[:, 2] = np.arange(10)  # prior_claim_count 0..9 in the reference
    pre = Preprocessor().fit(X)
    probe = np.zeros((3, N_FEATURES))
    probe[:, 2] = [9, 20, 200]
    S = pre.transform(probe)[:, 2]
    assert S[0] < S[1] < S[2] <= 1.0
    assert np.isclose(S[0], 0.75)


def test_preprocessor_rejects_wrong_shape_and_unfitted():
    with pytest.raises(ValueError):
        Preprocessor().fit(np.ones((3, N_FEATURES + 1)))
    with pytest.raises(RuntimeError):
        Preprocessor().transform(np.ones((3, N_FEATURES)))
