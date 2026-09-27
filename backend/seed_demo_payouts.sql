-- Demo only: give the two quantum demo claims (quantum/results/demo_claims.sql) the claimed amount and payout
-- destination a customer would have entered, so a manager can approve and pay them in the demo.
-- destination hash = sha256("demo bank|0000054321") (security/ledger.ts destinationHash); only last4 is stored.
UPDATE claims SET claimed_amount_cents = 1250000, payout_bank_name = 'Demo Bank', payout_account_holder = 'Mike',
  payout_account_last4 = '4321', payout_destination_hash = '585735d72f4ba75d9f34912cbe347afc33d8a4013714e06f6bc7215fece94513', payout_details_updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
WHERE id = 'claim_demo_normal' AND payout_destination_hash IS NULL;
UPDATE claims SET claimed_amount_cents = 4800000, payout_bank_name = 'Demo Bank', payout_account_holder = 'Mike',
  payout_account_last4 = '4321', payout_destination_hash = '585735d72f4ba75d9f34912cbe347afc33d8a4013714e06f6bc7215fece94513', payout_details_updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
WHERE id = 'claim_demo_unusual' AND payout_destination_hash IS NULL;
