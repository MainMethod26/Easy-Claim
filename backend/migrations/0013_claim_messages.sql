-- Claim hand-offs (27 Sep 2026): what staff ask for and what the customer answers, kept with the claim.
--
-- kind:
--   info_request    staff moved the claim to Info Needed and said what they need
--   customer_reply  the customer answered an information request (claim goes back to Screening)
--   appeal          the customer's reason for appealing a rejection
--   withdraw        the customer's (optional) reason for withdrawing
--   message         a general message between the customer and the insurer's claim staff
-- Rows are insert-only (like audit_events): the conversation is part of the claim's record.

CREATE TABLE IF NOT EXISTS claim_messages (
    id TEXT PRIMARY KEY,
    claim_id TEXT NOT NULL REFERENCES claims(id),
    tenant_id TEXT REFERENCES tenants(id),
    author_id TEXT NOT NULL,
    author_role TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('info_request', 'customer_reply', 'appeal', 'withdraw', 'message')),
    body TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_claim_messages_claim ON claim_messages(claim_id, created_at);
CREATE INDEX IF NOT EXISTS idx_claim_messages_author ON claim_messages(author_id, created_at);

CREATE TRIGGER IF NOT EXISTS claim_messages_no_update BEFORE UPDATE ON claim_messages
BEGIN SELECT RAISE(ABORT, 'claim_messages is append-only'); END;
CREATE TRIGGER IF NOT EXISTS claim_messages_no_delete BEFORE DELETE ON claim_messages
BEGIN SELECT RAISE(ABORT, 'claim_messages is append-only'); END;
