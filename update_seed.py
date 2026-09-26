import os

content = """-- Seed South African Insurance Data

-- Users
INSERT INTO users (id, first_name, last_name, id_number, email, phone, address, risk_profile, kyc_status) VALUES 
('user123', 'Sipho', 'Nkosi', '8505125021087', 'sipho.nkosi@example.co.za', '+27 82 123 4567', '123 Nelson Mandela Drive, Sandton, 2196', 'Low', 'Verified'),
('user456', 'Lerato', 'Mofokeng', '9003180123086', 'lerato.m@example.co.za', '+27 73 987 6543', '45 Vilakazi Street, Orlando West, Soweto', 'Medium', 'Verified'),
('user789', 'Johan', 'van der Merwe', '7811225021085', 'johan.vdm@example.co.za', '+27 84 555 1234', '12 Kloof Street, Gardens, Cape Town', 'Low', 'Verified');

-- Consents
INSERT INTO consents (id, user_id, consent_name, status) VALUES
('c_01', 'user123', 'POPIA Data Processing', 'Granted'),
('c_02', 'user123', 'Marketing Communications', 'Declined'),
('c_03', 'user123', 'Medical Records Sharing (Discovery)', 'Granted'),
('c_04', 'user456', 'POPIA Data Processing', 'Granted');

-- Mandates
INSERT INTO mandates (id, user_id, provider_name, bank_name, account_ending, amount, next_deduction, status) VALUES
('man_01', 'user123', 'Discovery Health', 'Standard Bank', '4567', 2450.00, '2026-10-01', 'Active'),
('man_02', 'user123', 'Sanlam', 'Standard Bank', '4567', 850.00, '2026-10-01', 'Active'),
('man_03', 'user456', 'OUTsurance', 'FNB', '1234', 1100.00, '2026-10-01', 'Active');

-- Policies
INSERT INTO policies (id, user_id, provider, plan_name, insurance_type, premium, status, asset_details, start_date) VALUES 
('pol_disc_001', 'user123', 'Discovery Health', 'Executive Plan', 'Health Insurance', 2450.00, 'Active', '{"medical_aid_number": "DH987654321"}', '2020-01-01'),
('pol_sanlam_002', 'user123', 'Sanlam', 'Comprehensive Life Cover', 'Life Insurance', 850.00, 'Active', '{"beneficiary": "Nomsa Nkosi"}', '2021-06-15'),
('pol_out_003', 'user456', 'OUTsurance', 'Car Insurance', 'Motor Vehicle Insurance', 1100.00, 'Active', '{"vehicle": "VW Polo 2022", "vin": "WVWZZZ6RZM", "plate": "CA 123 456"}', '2022-03-10'),
('pol_mom_004', 'user789', 'Momentum', 'Multiply Health', 'Health Insurance', 540.00, 'Active', '{"medical_aid_number": "MOM123456"}', '2019-11-01'),
('pol_oldm_005', 'user123', 'Old Mutual', 'Protect Family Funeral Plan', 'Funeral Insurance', 150.00, 'Active', '{"covered_members": 5}', '2018-05-20');

-- Claims
INSERT INTO claims (id, user_id, policy_id, stage, status, incident_date, cause_of_loss, claim_amount, approved_amount, risk_score, routing) VALUES 
('claim_disc_101', 'user123', 'pol_disc_001', 'REVIEW', 'Processing', '2026-09-10', 'Hospitalization', 15000.00, NULL, 12.5, 'Manual-Review'),
('claim_sanlam_102', 'user123', 'pol_sanlam_002', 'PAID', 'Closed', '2026-08-01', 'Disability Claim', 50000.00, 50000.00, 5.0, 'Fast-Track'),
('claim_out_103', 'user456', 'pol_out_003', 'SUBMITTED', 'Processing', '2026-09-20', 'Accident - Bumper Damage', 8500.00, NULL, 45.0, 'Investigator'),
('claim_mom_104', 'user789', 'pol_mom_004', 'INFO_NEEDED', 'Paused', '2026-09-15', 'Pharmacy Script', 1200.00, NULL, 8.0, 'Fast-Track');

-- Documents
INSERT INTO documents (id, user_id, claim_id, document_type, file_url, ocr_status, ocr_extracted_data) VALUES
('doc_01', 'user123', 'claim_disc_101', 'Hospital Invoice', 's3://easyclaim/docs/doc_01.pdf', 'Completed', '{"total": 15000, "hospital": "Netcare"}'),
('doc_02', 'user123', 'claim_sanlam_102', 'Medical Report', 's3://easyclaim/docs/doc_02.pdf', 'Completed', '{"doctor": "Dr. Smith", "condition": "Cleared"}'),
('doc_03', 'user456', 'claim_out_103', 'Police Report', 's3://easyclaim/docs/doc_03.pdf', 'Pending', NULL);

-- Audit Logs
INSERT INTO audit_logs (id, user_id, event, ip_address, location, details) VALUES
('audit_01', 'user123', 'LOGIN_SUCCESS', '197.85.12.34', 'Johannesburg, ZA', '{"browser": "Chrome"}'),
('audit_02', 'user123', 'CLAIM_SUBMITTED', '197.85.12.34', 'Johannesburg, ZA', '{"claim_id": "claim_disc_101"}'),
('audit_03', 'user456', 'POLICY_CREATED', '105.10.22.45', 'Cape Town, ZA', '{"policy_id": "pol_out_003"}');
"""

with open('backend/seed_sa_data.sql', 'w') as f:
    f.write(content)
