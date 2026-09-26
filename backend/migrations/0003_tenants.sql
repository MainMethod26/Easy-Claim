-- Phase 1: insurer tenants. See docs/phase-reports/PHASE_01_TENANT_MODEL.md.
--
-- A tenant is an insurer organisation. Insurer staff (ASSESSOR / MANAGER) belong to exactly
-- one tenant (tenant_id claim in their token). Policies and claims belong to the insurer
-- that underwrites them. Customers are platform-level and have no tenant.

CREATE TABLE IF NOT EXISTS tenants (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

-- Demo insurers matching seed_sa_data.sql. Reference data, inserted here so the backfill
-- below satisfies the foreign key on existing local databases.
INSERT OR IGNORE INTO tenants (id, name) VALUES
('ins_discovery', 'Discovery Health'),
('ins_sanlam', 'Sanlam'),
('ins_outsurance', 'OUTsurance'),
('ins_momentum', 'Momentum'),
('ins_oldmutual', 'Old Mutual');

ALTER TABLE policies ADD COLUMN tenant_id TEXT REFERENCES tenants(id);
ALTER TABLE claims ADD COLUMN tenant_id TEXT REFERENCES tenants(id);

-- Which tenant performed the action (NULL for customers). Insert-only like the rest of the table.
ALTER TABLE audit_events ADD COLUMN actor_tenant_id TEXT;

-- Backfill for local databases created from the original seed before this migration.
-- Only the five known seed policies are assigned (by id, never by name), so no other
-- pre-existing row is silently re-homed into a demo insurer. Any other policy keeps
-- tenant_id NULL, which every insurer-side check treats as "visible to no insurer".
-- New rows are written with tenant_id by the application.
UPDATE policies SET tenant_id = 'ins_discovery'  WHERE tenant_id IS NULL AND id = 'pol_disc_001';
UPDATE policies SET tenant_id = 'ins_sanlam'     WHERE tenant_id IS NULL AND id = 'pol_sanlam_002';
UPDATE policies SET tenant_id = 'ins_outsurance' WHERE tenant_id IS NULL AND id = 'pol_out_003';
UPDATE policies SET tenant_id = 'ins_momentum'   WHERE tenant_id IS NULL AND id = 'pol_mom_004';
UPDATE policies SET tenant_id = 'ins_oldmutual'  WHERE tenant_id IS NULL AND id = 'pol_oldm_005';
UPDATE claims SET tenant_id = (SELECT p.tenant_id FROM policies p WHERE p.id = claims.policy_id)
WHERE tenant_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_policies_tenant ON policies(tenant_id);
CREATE INDEX IF NOT EXISTS idx_claims_tenant ON claims(tenant_id);
