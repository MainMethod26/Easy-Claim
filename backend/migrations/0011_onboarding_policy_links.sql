-- Insurer onboarding and policy linking (27 Sep 2026).
--
-- 1. insurer_applications: an insurance company applies on the public site; the platform operator
--    (SUPERADMIN) approves, which creates the tenant and its first INSURER_ADMIN in one batch, or rejects.
--    The applicant's password is stored only as a PBKDF2 hash and is cleared once the application is decided.
-- 2. policies.policy_number: the insurer's own policy number, unique per insurer.
-- 3. policy_link_requests: a customer asks to link an existing policy (insurer + policy number); the
--    insurer's admin approves, which creates the policy row for that customer, or rejects.

CREATE TABLE IF NOT EXISTS insurer_applications (
    id TEXT PRIMARY KEY,
    company_name TEXT NOT NULL,
    fsp_number TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    admin_username TEXT NOT NULL,
    admin_display_name TEXT NOT NULL,
    admin_password_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    tenant_id TEXT REFERENCES tenants(id),
    decision_reason TEXT,
    decided_by TEXT,
    decided_at TEXT,
    created_at TEXT NOT NULL,
    -- An approved application always names the tenant it created.
    CHECK ((status = 'approved') = (tenant_id IS NOT NULL))
);
-- One pending application per requested admin username and per FSP licence number.
CREATE UNIQUE INDEX IF NOT EXISTS idx_insurer_app_pending_username ON insurer_applications(admin_username) WHERE status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS idx_insurer_app_pending_fsp ON insurer_applications(fsp_number) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_insurer_app_status ON insurer_applications(status, created_at);

ALTER TABLE policies ADD COLUMN policy_number TEXT;
ALTER TABLE policies ADD COLUMN created_at TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_policies_tenant_number ON policies(tenant_id, policy_number) WHERE policy_number IS NOT NULL;

CREATE TABLE IF NOT EXISTS policy_link_requests (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    tenant_id TEXT NOT NULL REFERENCES tenants(id),
    policy_number TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    policy_id TEXT REFERENCES policies(id),
    decision_reason TEXT,
    decided_by TEXT,
    decided_at TEXT,
    created_at TEXT NOT NULL,
    CHECK ((status = 'approved') = (policy_id IS NOT NULL))
);
-- One pending request per policy number at an insurer (whoever asks).
CREATE UNIQUE INDEX IF NOT EXISTS idx_policy_link_pending ON policy_link_requests(tenant_id, policy_number) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_policy_link_tenant ON policy_link_requests(tenant_id, status, created_at);
CREATE INDEX IF NOT EXISTS idx_policy_link_user ON policy_link_requests(user_id, created_at);
