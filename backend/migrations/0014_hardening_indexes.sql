-- Hardening and scale (27 Sep 2026).
--
-- 1. users.token_version: tokens carry it as `ver`; requireActor rejects a token whose version no longer
--    matches, so a password change or an account disable revokes existing sessions immediately.
-- 2. insurer_applications.ip_hash: SHA-256 of the applicant's IP, used only to throttle the public form
--    per address (the raw IP is never stored).
-- 3. Indexes for the queries the dashboards, audit views, claim queues and the expiry job run.

ALTER TABLE users ADD COLUMN token_version INTEGER NOT NULL DEFAULT 0;

ALTER TABLE insurer_applications ADD COLUMN ip_hash TEXT;
CREATE INDEX IF NOT EXISTS idx_insurer_app_ip ON insurer_applications(ip_hash, created_at);

CREATE INDEX IF NOT EXISTS idx_audit_occurred ON audit_events(occurred_at);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_events(action, occurred_at);
CREATE INDEX IF NOT EXISTS idx_audit_actor_tenant ON audit_events(actor_tenant_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_audit_outcome ON audit_events(outcome, occurred_at);

CREATE INDEX IF NOT EXISTS idx_claims_tenant_stage ON claims(tenant_id, stage, created_at);
CREATE INDEX IF NOT EXISTS idx_claims_stage_updated ON claims(stage, updated_at);
CREATE INDEX IF NOT EXISTS idx_claims_user ON claims(user_id, created_at);

CREATE INDEX IF NOT EXISTS idx_decisions_tenant ON claim_decisions(tenant_id, decided_at);
CREATE INDEX IF NOT EXISTS idx_decisions_claim ON claim_decisions(claim_id, decided_at);
CREATE INDEX IF NOT EXISTS idx_payouts_tenant ON payouts(tenant_id, initiated_at);

CREATE INDEX IF NOT EXISTS idx_request_documents_request ON request_documents(request_id);
