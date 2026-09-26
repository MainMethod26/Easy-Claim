-- Phase 4 completion: tamper evidence for advisory screening signals.
-- See docs/quantum/QUANTUM_SECURITY_BOUNDARY.md.
--
-- Signals are produced offline (quantum/experiment.py) and imported. An import replaces the
-- row (INSERT OR REPLACE = delete + insert), which is how a new model run is published. What
-- must not happen silently is an in-place edit of a stored score. The Worker records a SHA-256
-- digest of the row in audit_events every time the signal is attached or read, and in
-- claim_decisions.risk_signal at decision time, so any later difference is detectable.

-- When the row was written (set on insert; re-imports get a new timestamp).
ALTER TABLE screening_signals ADD COLUMN imported_at TEXT;

-- In-place edits of a stored signal are refused; publish a new model run instead.
CREATE TRIGGER IF NOT EXISTS screening_signals_no_update BEFORE UPDATE ON screening_signals
BEGIN SELECT RAISE(ABORT, 'screening_signals rows are replaced by import, never edited in place'); END;
