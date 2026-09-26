-- Seed South African Insurance Data (demo only)
-- Tenants (insurers) are created by migrations/0003_tenants.sql:
--   ins_discovery, ins_sanlam, ins_outsurance, ins_momentum, ins_oldmutual
-- Customers are platform-level: user123 holds policies with three different insurers.

INSERT INTO policies (id, user_id, plan_name, status, tenant_id) VALUES
('pol_disc_001', 'user123', 'Discovery Health Executive Plan', 'Active', 'ins_discovery'),
('pol_sanlam_002', 'user123', 'Sanlam Life Cover', 'Active', 'ins_sanlam'),
('pol_out_003', 'user456', 'OUTsurance Car Insurance', 'Pending', 'ins_outsurance'),
('pol_mom_004', 'user789', 'Momentum Multiply Health', 'Active', 'ins_momentum'),
('pol_oldm_005', 'user123', 'Old Mutual Funeral Plan', 'Active', 'ins_oldmutual');

INSERT INTO claims (id, user_id, policy_id, stage, status, tenant_id) VALUES
('claim_disc_101', 'user123', 'pol_disc_001', 'Review', 'Processing', 'ins_discovery'),
('claim_sanlam_102', 'user123', 'pol_sanlam_002', 'Decision', 'Approved', 'ins_sanlam'),
('claim_mom_103', 'user789', 'pol_mom_004', 'Submitted', 'Pending', 'ins_momentum');
