-- Phase 2: evidence security. See docs/security/EVIDENCE_SECURITY.md and
-- docs/phase-reports/PHASE_02_REPORT.md.

-- Copied from the parent claim at upload time (never from the client), so evidence can be
-- listed/scoped per tenant without joining to claims on every query.
ALTER TABLE evidence ADD COLUMN tenant_id TEXT REFERENCES tenants(id);

-- Sanitized (server-side) original filename, kept only as display metadata. Never used to
-- build the storage key or a filesystem/object path.
ALTER TABLE evidence ADD COLUMN display_name TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_evidence_tenant ON evidence(tenant_id);
