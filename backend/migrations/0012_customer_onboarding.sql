-- Customer onboarding with documents (27 Sep 2026). See src/onboarding/customerOnboarding.ts.
--
-- 1. users.easyclaim_id: every customer's unique, shareable EasyClaim ID (EC-XXXX-XXXX). Insurers can look a
--    customer up by it (exact match only). New customers get one at registration; existing ones are backfilled.
-- 2. customer_profiles: the details a customer shares with the insurers they apply to. The SA ID number is
--    stored AES-GCM encrypted (key: PII_KEY secret) plus its last 4 digits for masked display.
-- 3. tenant_document_requirements: each insurer's own list of documents it needs before approving.
-- 4. policy_link_requests gains status 'more_info' (insurer asked for something) and info_message.
-- 5. request_documents: files a customer uploads for a request (private R2 objects), and whether the
--    insurer has checked each one.

ALTER TABLE users ADD COLUMN easyclaim_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_easyclaim_id ON users(easyclaim_id) WHERE easyclaim_id IS NOT NULL;
UPDATE users SET easyclaim_id = 'EC-' || upper(substr(hex(randomblob(2)), 1, 4)) || '-' || upper(substr(hex(randomblob(2)), 1, 4))
WHERE role = 'CUSTOMER' AND easyclaim_id IS NULL;

CREATE TABLE IF NOT EXISTS customer_profiles (
    user_id TEXT PRIMARY KEY REFERENCES users(id),
    legal_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    date_of_birth TEXT NOT NULL,
    id_number_enc TEXT NOT NULL,
    id_number_last4 TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tenant_document_requirements (
    tenant_id TEXT NOT NULL REFERENCES tenants(id),
    doc_key TEXT NOT NULL,
    label TEXT NOT NULL,
    required INTEGER NOT NULL DEFAULT 1 CHECK (required IN (0, 1)),
    sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (tenant_id, doc_key)
);
INSERT OR IGNORE INTO tenant_document_requirements (tenant_id, doc_key, label, required, sort_order)
SELECT id, 'id_document', 'ID document (green book or smart card)', 1, 1 FROM tenants;
INSERT OR IGNORE INTO tenant_document_requirements (tenant_id, doc_key, label, required, sort_order)
SELECT id, 'proof_of_address', 'Proof of address (not older than 3 months)', 1, 2 FROM tenants;
INSERT OR IGNORE INTO tenant_document_requirements (tenant_id, doc_key, label, required, sort_order)
SELECT id, 'policy_schedule', 'Policy schedule', 1, 3 FROM tenants;

-- Rebuild policy_link_requests to widen the status CHECK (SQLite cannot alter a CHECK in place).
CREATE TABLE policy_link_requests_new (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    tenant_id TEXT NOT NULL REFERENCES tenants(id),
    policy_number TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'more_info', 'approved', 'rejected')),
    policy_id TEXT REFERENCES policies(id),
    info_message TEXT,
    decision_reason TEXT,
    decided_by TEXT,
    decided_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT,
    CHECK ((status = 'approved') = (policy_id IS NOT NULL))
);
INSERT INTO policy_link_requests_new (id, user_id, tenant_id, policy_number, status, policy_id, decision_reason, decided_by, decided_at, created_at)
SELECT id, user_id, tenant_id, policy_number, status, policy_id, decision_reason, decided_by, decided_at, created_at FROM policy_link_requests;
DROP TABLE policy_link_requests;
ALTER TABLE policy_link_requests_new RENAME TO policy_link_requests;
-- One OPEN request (pending or waiting for the customer) per policy number at an insurer.
CREATE UNIQUE INDEX IF NOT EXISTS idx_policy_link_open ON policy_link_requests(tenant_id, policy_number) WHERE status IN ('pending', 'more_info');
CREATE INDEX IF NOT EXISTS idx_policy_link_tenant ON policy_link_requests(tenant_id, status, created_at);
CREATE INDEX IF NOT EXISTS idx_policy_link_user ON policy_link_requests(user_id, created_at);

CREATE TABLE IF NOT EXISTS request_documents (
    id TEXT PRIMARY KEY,
    request_id TEXT NOT NULL REFERENCES policy_link_requests(id),
    doc_key TEXT NOT NULL,
    storage_key TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    sha256 TEXT NOT NULL,
    display_name TEXT NOT NULL,
    uploaded_at TEXT NOT NULL,
    verified INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0, 1)),
    verified_by TEXT,
    verified_at TEXT,
    UNIQUE (request_id, doc_key)
);
