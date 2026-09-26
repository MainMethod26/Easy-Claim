-- Security baseline (cyber branch). See docs/security/SECURITY_IMPLEMENTATION_PLAN.md.

-- Claim fields written only by the server (screening answers + timestamps).
ALTER TABLE claims ADD COLUMN category TEXT;
ALTER TABLE claims ADD COLUMN cause_of_loss TEXT;
ALTER TABLE claims ADD COLUMN incident_date TEXT;
ALTER TABLE claims ADD COLUMN created_at TEXT;
ALTER TABLE claims ADD COLUMN updated_at TEXT;

CREATE INDEX IF NOT EXISTS idx_claims_user ON claims(user_id);
CREATE INDEX IF NOT EXISTS idx_policies_user ON policies(user_id);

-- Append-only security audit trail. No route updates or deletes rows.
CREATE TABLE IF NOT EXISTS audit_events (
    id TEXT PRIMARY KEY,
    occurred_at TEXT NOT NULL,
    actor_id TEXT,
    actor_role TEXT,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    outcome TEXT NOT NULL CHECK (outcome IN ('success', 'denied', 'failure')),
    request_id TEXT,
    details TEXT
);
CREATE INDEX IF NOT EXISTS idx_audit_resource ON audit_events(resource_type, resource_id);

-- Defence in depth: reject UPDATE/DELETE on audit rows at the database layer.
CREATE TRIGGER IF NOT EXISTS audit_events_no_update BEFORE UPDATE ON audit_events
BEGIN SELECT RAISE(ABORT, 'audit_events is append-only'); END;
CREATE TRIGGER IF NOT EXISTS audit_events_no_delete BEFORE DELETE ON audit_events
BEGIN SELECT RAISE(ABORT, 'audit_events is append-only'); END;

-- Evidence metadata for when real upload/storage is added (not used by any route yet).
CREATE TABLE IF NOT EXISTS evidence (
    id TEXT PRIMARY KEY,
    claim_id TEXT NOT NULL REFERENCES claims(id),
    uploaded_by TEXT NOT NULL,
    storage_key TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    sha256 TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_evidence_claim ON evidence(claim_id);
