-- Seed South African Insurance Data

INSERT INTO policies (id, user_id, plan_name, status) VALUES 
('pol_disc_001', 'user123', 'Discovery Health Executive Plan', 'Active'),
('pol_sanlam_002', 'user123', 'Sanlam Life Cover', 'Active'),
('pol_out_003', 'user456', 'OUTsurance Car Insurance', 'Pending'),
('pol_mom_004', 'user789', 'Momentum Multiply Health', 'Active'),
('pol_oldm_005', 'user123', 'Old Mutual Funeral Plan', 'Active');

INSERT INTO claims (id, user_id, policy_id, stage, status) VALUES 
('claim_disc_101', 'user123', 'pol_disc_001', 'Review', 'Processing'),
('claim_sanlam_102', 'user123', 'pol_sanlam_002', 'Decision', 'Approved'),
('claim_mom_103', 'user789', 'pol_mom_004', 'Submitted', 'Pending');
