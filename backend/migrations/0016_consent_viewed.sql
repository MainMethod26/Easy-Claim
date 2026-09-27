-- Migration 0016: when the customer first opened a pending consent form ("Customer is reading", like
-- an e-signature "viewed" status). Set once by GET /consents/:id for the owner; audited as consent.viewed.
ALTER TABLE consents ADD COLUMN viewed_at TEXT;
