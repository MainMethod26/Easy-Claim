-- Accounts (team role model, 26 Sep 2026): SUPERADMIN (platform), INSURER_ADMIN (one insurer / tenant),
-- CUSTOMER (platform-level). Passwords are PBKDF2-SHA256 hashes (src/security/password.ts); never plain text.
-- users.id is the token subject (`sub`) and the value stored in policies.user_id / claims.user_id, so the
-- seeded demo customers keep their historical ids (user123, ...).
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('CUSTOMER', 'INSURER_ADMIN', 'SUPERADMIN')),
    tenant_id TEXT REFERENCES tenants(id),
    display_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
    created_at TEXT NOT NULL,
    created_by TEXT,
    -- Exactly the insurer admins belong to a tenant; customers and superadmins never do.
    CHECK ((role = 'INSURER_ADMIN') = (tenant_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_users_tenant ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
