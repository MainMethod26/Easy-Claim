-- Phase 3: decision records and simulated payouts. See docs/phase-reports/PHASE_03_REPORT.md.
--
-- Principle: the client never defines the authoritative decision or payout state. The
-- customer supplies the claimed amount and payout destination BEFORE submission; the
-- decision-maker records the outcome and (for approvals) the approved amount, which can
-- never exceed the claimed amount; the payout uses only the recorded decision and a
-- destination whose hash must still match the one snapshotted at decision time.

-- Payout inputs captured on the claim while it is still editable by the owner.
ALTER TABLE claims ADD COLUMN claimed_amount_cents INTEGER;
ALTER TABLE claims ADD COLUMN payout_bank_name TEXT;
ALTER TABLE claims ADD COLUMN payout_account_holder TEXT;
ALTER TABLE claims ADD COLUMN payout_account_last4 TEXT;
-- SHA-256 of bank name + full account number; the full number is never stored.
ALTER TABLE claims ADD COLUMN payout_destination_hash TEXT;
ALTER TABLE claims ADD COLUMN payout_details_updated_at TEXT;

-- Insert-only decision record: who decided what, when, on which claim, with which inputs.
CREATE TABLE IF NOT EXISTS claim_decisions (
    id TEXT PRIMARY KEY,
    claim_id TEXT NOT NULL REFERENCES claims(id),
    tenant_id TEXT REFERENCES tenants(id),
    outcome TEXT NOT NULL CHECK (outcome IN ('Approved', 'Rejected')),
    reason TEXT NOT NULL,
    previous_stage TEXT NOT NULL,
    claimed_amount_cents INTEGER,
    approved_amount_cents INTEGER,
    destination_hash TEXT,
    actor_id TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    decided_at TEXT NOT NULL,
    request_id TEXT,
    rules_version TEXT NOT NULL,
    -- Reserved for later phases: Phase 2 evidence digest, screening/risk signal, ML-DSA signature.
    evidence_digest TEXT,
    risk_signal TEXT,
    integrity_signature TEXT
);
CREATE INDEX IF NOT EXISTS idx_decisions_claim ON claim_decisions(claim_id, decided_at);
CREATE TRIGGER IF NOT EXISTS claim_decisions_no_update BEFORE UPDATE ON claim_decisions
BEGIN SELECT RAISE(ABORT, 'claim_decisions is append-only'); END;
CREATE TRIGGER IF NOT EXISTS claim_decisions_no_delete BEFORE DELETE ON claim_decisions
BEGIN SELECT RAISE(ABORT, 'claim_decisions is append-only'); END;

-- Insert-only, one payout per claim (simulated; no money moves).
CREATE TABLE IF NOT EXISTS payouts (
    id TEXT PRIMARY KEY,
    claim_id TEXT NOT NULL UNIQUE REFERENCES claims(id),
    tenant_id TEXT REFERENCES tenants(id),
    decision_id TEXT NOT NULL REFERENCES claim_decisions(id),
    amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
    destination_hash TEXT NOT NULL,
    destination_last4 TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('simulated')),
    idempotency_key TEXT,
    initiated_by TEXT NOT NULL,
    initiated_role TEXT NOT NULL,
    initiated_at TEXT NOT NULL,
    request_id TEXT
);
CREATE TRIGGER IF NOT EXISTS payouts_no_update BEFORE UPDATE ON payouts
BEGIN SELECT RAISE(ABORT, 'payouts is append-only'); END;
CREATE TRIGGER IF NOT EXISTS payouts_no_delete BEFORE DELETE ON payouts
BEGIN SELECT RAISE(ABORT, 'payouts is append-only'); END;
