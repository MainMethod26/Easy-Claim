-- Users (Identity & KYC)
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    id_number TEXT UNIQUE NOT NULL, -- SA ID Number or Passport
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    address TEXT,
    risk_profile TEXT DEFAULT 'Low', -- Low, Medium, High
    kyc_status TEXT DEFAULT 'Pending', -- Pending, Verified, Rejected
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Consents (POPIA & Data Privacy)
CREATE TABLE IF NOT EXISTS consents (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    consent_name TEXT NOT NULL,
    status TEXT NOT NULL, -- Granted, Declined, Revoked
    granted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Mandates (Debit Orders / Payments)
CREATE TABLE IF NOT EXISTS mandates (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    provider_name TEXT NOT NULL,
    bank_name TEXT NOT NULL,
    account_ending TEXT NOT NULL,
    amount REAL NOT NULL,
    next_deduction DATE,
    status TEXT DEFAULT 'Active', -- Active, Cancelled, Failed
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Policies
CREATE TABLE IF NOT EXISTS policies (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    insurance_type TEXT NOT NULL, -- Mobile Device, Home, Motor, Health, Life
    premium REAL NOT NULL,
    status TEXT DEFAULT 'Pending', -- Active, Pending, Cancelled, Expired
    asset_details JSON, -- Stores VINs, IMEIs, Addresses based on insurance_type
    start_date DATE,
    end_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Policy Requirements (Onboarding Captures)
CREATE TABLE IF NOT EXISTS policy_requirements (
    id TEXT PRIMARY KEY,
    policy_id TEXT NOT NULL,
    requirement_type TEXT NOT NULL, -- e.g., 'Motor Vehicle Insurance'
    payload JSON NOT NULL, -- The full KYC and asset capture payload
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (policy_id) REFERENCES policies (id)
);

-- Claims (Standard 6-Stage Model)
CREATE TABLE IF NOT EXISTS claims (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    policy_id TEXT NOT NULL,
    stage TEXT DEFAULT 'SUBMITTED', -- SUBMITTED, VERIFIED, SCREENING, REVIEW, DECISION, PAID, INFO_NEEDED, REJECTED, APPEAL
    status TEXT DEFAULT 'Processing', -- Processing, Approved, Declined, Closed
    incident_date DATE,
    cause_of_loss TEXT,
    claim_amount REAL,
    approved_amount REAL,
    risk_score REAL,
    routing TEXT, -- Fast-Track, Manual-Review, Investigator
    decision_reason TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (policy_id) REFERENCES policies (id)
);

-- Documents (OCR & Evidence)
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    claim_id TEXT, -- Can be null if uploaded during policy onboarding
    document_type TEXT NOT NULL, -- e.g., 'Invoice', 'Police Report', 'ID'
    file_url TEXT NOT NULL,
    ocr_status TEXT DEFAULT 'Pending', -- Pending, Completed, Failed
    ocr_extracted_data JSON,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (claim_id) REFERENCES claims (id)
);

-- Audit Logs (Tracking all activities)
CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    event TEXT NOT NULL,
    ip_address TEXT,
    location TEXT,
    details JSON,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id)
);
