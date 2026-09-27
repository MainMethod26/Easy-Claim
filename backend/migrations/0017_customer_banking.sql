-- Banking details move from each claim to the customer's profile (27 Sep 2026).
--
-- A customer saves one payout account on their profile (Profile › Banking details) instead of typing it
-- into every claim. When a claim is submitted, the profile account is copied onto the claim (the same
-- claims.payout_* columns as before); a decision then freezes that destination and /pay pays only to it.
-- As before, the full account number is never stored: only the bank, holder, last 4 digits and the
-- destination hash (src/security/ledger.ts destinationHash).

CREATE TABLE IF NOT EXISTS customer_banking (
    user_id TEXT PRIMARY KEY REFERENCES users(id),
    bank_name TEXT NOT NULL,
    account_holder TEXT NOT NULL,
    account_last4 TEXT NOT NULL,
    destination_hash TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
