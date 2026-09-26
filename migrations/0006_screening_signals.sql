-- Phase 4 (quantum track): advisory screening signals. See docs/quantum/QUANTUM_SCREENING_ARCHITECTURE.md.
--
-- One row per claim, written ONLY by the offline research pipeline (quantum/experiment.py ->
-- results/screening_signals.sql, imported with wrangler d1 execute). No API route inserts or
-- updates this table, so no client can submit a score. The Worker only reads it, behind the
-- Phase 1 authentication, tenant and ownership checks, and returns it as screening context.
-- A signal never changes claims.stage or claims.status; the state machine is untouched.
CREATE TABLE IF NOT EXISTS screening_signals (
    claim_id TEXT PRIMARY KEY REFERENCES claims(id),
    model_version TEXT NOT NULL,
    classical_anomaly REAL NOT NULL CHECK (classical_anomaly >= 0 AND classical_anomaly <= 1),
    quantum_anomaly REAL NOT NULL CHECK (quantum_anomaly >= 0 AND quantum_anomaly <= 1),
    interpretation TEXT NOT NULL CHECK (interpretation IN ('NORMAL', 'UNUSUAL', 'HIGH_ANOMALY')),
    execution TEXT NOT NULL CHECK (execution IN ('simulator', 'hardware')),
    feature_snapshot TEXT,
    computed_at TEXT NOT NULL
);
