-- Seed South African Insurance Data (demo only)
-- Tenants (insurers) are created by migrations/0003_tenants.sql:
--   ins_discovery, ins_sanlam, ins_outsurance, ins_momentum, ins_oldmutual
INSERT OR IGNORE INTO users (id, first_name, last_name, id_number, email) VALUES
('user123', 'Thabo', 'Mokoena', '9201015000000', 'thabo@example.com'),
('user456', 'Lerato', 'Nkosi', '9301015000000', 'lerato@example.com'),
('user789', 'Sipho', 'Dlamini', '9401015000000', 'sipho@example.com');

INSERT OR IGNORE INTO policies (id, user_id, provider, plan_name, insurance_type, premium, status) VALUES
('pol_disc_001', 'user123', 'ins_discovery', 'Discovery Health Executive Plan', 'Health', 1500, 'Active'),
('pol_sanlam_002', 'user123', 'ins_sanlam', 'Sanlam Life Cover', 'Life', 500, 'Active'),
('pol_out_003', 'user456', 'ins_outsurance', 'OUTsurance Car Insurance', 'Motor', 800, 'Pending'),
('pol_mom_004', 'user789', 'ins_momentum', 'Momentum Multiply Health', 'Health', 1200, 'Active'),
('pol_oldm_005', 'user123', 'ins_oldmutual', 'Old Mutual Funeral Plan', 'Life', 200, 'Active');

INSERT OR IGNORE INTO claims (id, user_id, policy_id, stage, status) VALUES
('claim_disc_101', 'user123', 'pol_disc_001', 'REVIEW', 'Processing'),
('claim_sanlam_102', 'user123', 'pol_sanlam_002', 'DECISION', 'Approved'),
('claim_mom_103', 'user789', 'pol_mom_004', 'SUBMITTED', 'Pending');
