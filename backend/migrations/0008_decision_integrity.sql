-- Phase 5: post-quantum decision integrity (ML-DSA-65, FIPS 204). See docs/security/PQC_DECISION_INTEGRITY.md.
-- claim_decisions.integrity_signature was reserved in 0005; these columns record how it was produced.
-- All four are written once, at insert time, in the same D1 batch as the Review -> Decision transition;
-- the insert-only triggers from 0005 keep them immutable.

ALTER TABLE claim_decisions ADD COLUMN integrity_alg TEXT;          -- 'ML-DSA-65'
ALTER TABLE claim_decisions ADD COLUMN integrity_key_id TEXT;       -- 'mldsa65-' + first 16 hex of SHA-256(public key)
ALTER TABLE claim_decisions ADD COLUMN integrity_bundle_digest TEXT; -- SHA-256 of the canonical decision bundle
