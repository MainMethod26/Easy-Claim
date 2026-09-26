#!/usr/bin/env bash
# Phase 3 live demos against wrangler dev (127.0.0.1:8788), branch phase-3-decision-payout.
set -u
cd /c/Users/HomePC/Music/Hackathon/ec-merged
B=http://127.0.0.1:8788/api/v1
CT="Content-Type: application/json"
mint() { node scripts/mint-token.mjs "$@"; }
CA=$(mint --sub user123 --role CUSTOMER)
AA=$(mint --sub assessor_a1 --role ASSESSOR --tenant ins_discovery)
MA=$(mint --sub manager_a1 --role MANAGER --tenant ins_discovery)
MB=$(mint --sub manager_b1 --role MANAGER --tenant ins_sanlam)
s() { local label=$1 token=$2; shift 2; printf '[%s] %s\n' "$label" "$(curl -s -m 20 -w ' -> HTTP %{http_code}' -H "Authorization: Bearer $token" "$@" | cut -c1-190)"; }

ID=$(curl -s -m 20 -X POST -H "Authorization: Bearer $CA" -H "$CT" -d '{"policyId":"pol_disc_001","category":"Medical"}' $B/claims/initiate | node -pe 'JSON.parse(require("fs").readFileSync(0)).claimId')
echo "== Setup: customer files a claim for R4 200 with a payout destination, then submits"
echo "[initiate] $ID"
s "payout details (Draft)" "$CA" -X PUT -H "$CT" -d '{"claimedAmountCents":420000,"bankName":"Demo Bank","accountHolder":"Customer A","accountNumber":"62001234567890"}' $B/claims/$ID/payout-details
s "screening" "$CA" -X PATCH -H "$CT" -d '{"causeOfLoss":"Hospital admission","incidentDate":"2026-01-10"}' $B/claims/$ID/screening
s "submit" "$CA" -X POST $B/claims/$ID/submit
echo "== DEMO 2: illegal transition Submitted -> Paid"
s "manager pays a Submitted claim" "$MA" -X POST $B/claims/$ID/pay
s "decide with client-chosen state" "$MA" -X POST -H "$CT" -d '{"outcome":"Approved","reason":"x","state":"Paid"}' $B/claims/$ID/decide
echo "== Assessor prepares the claim (verify, screen, review)"
s "verify" "$AA" -X POST $B/claims/$ID/verify
s "screen" "$AA" -X POST $B/claims/$ID/screen
s "review" "$AA" -X POST $B/claims/$ID/review
echo "== DEMO 1: unauthorized decision"
s "customer approves own claim" "$CA" -X POST -H "$CT" -d '{"outcome":"Approved","reason":"I approve myself"}' $B/claims/$ID/decide
s "assessor decides" "$AA" -X POST -H "$CT" -d '{"outcome":"Approved","reason":"assessor try"}' $B/claims/$ID/decide
s "cross-tenant manager decides" "$MB" -X POST -H "$CT" -d '{"outcome":"Approved","reason":"other insurer"}' $B/claims/$ID/decide
echo "== DEMO 3: payout manipulation (legitimate R4 200, attacker R420 000)"
s "approve R420 000" "$MA" -X POST -H "$CT" -d '{"outcome":"Approved","reason":"inflated","approvedAmountCents":42000000}' $B/claims/$ID/decide
echo "== DEMO 5 (part 1): legitimate decision"
s "manager approves (full claimed amount)" "$MA" -X POST -H "$CT" -d '{"outcome":"Approved","reason":"Documents verified, within cover"}' $B/claims/$ID/decide
s "customer reads decision" "$CA" $B/claims/$ID/decision
s "pay with client amount R420 000" "$MA" -X POST -H "$CT" -d '{"amount":42000000}' $B/claims/$ID/pay
echo "== DEMO 4: payout destination attack after approval"
s "customer changes destination" "$CA" -X PUT -H "$CT" -d '{"claimedAmountCents":420000,"bankName":"Attacker Bank","accountHolder":"Someone Else","accountNumber":"99990000111122"}' $B/claims/$ID/payout-details
echo "[direct DB tamper of the destination hash (simulating a compromised path)]"
npx wrangler d1 execute easy-claim-db --local --command "UPDATE claims SET payout_destination_hash = 'deadbeef', payout_account_last4 = '1122' WHERE id = '$ID'" >/dev/null 2>&1
s "pay after tamper" "$MA" -X POST $B/claims/$ID/pay
echo "[restore the legitimate destination hash]"
H=$(node --input-type=module -e "const d=await crypto.subtle.digest('SHA-256',new TextEncoder().encode('demo bank|62001234567890'));console.log([...new Uint8Array(d)].map(b=>b.toString(16).padStart(2,'0')).join(''))")
npx wrangler d1 execute easy-claim-db --local --command "UPDATE claims SET payout_destination_hash = '$H', payout_account_last4 = '7890' WHERE id = '$ID'" >/dev/null 2>&1
echo "== DEMO 5 (part 2): legitimate payout, replay, cross-tenant"
s "cross-tenant manager pays" "$MB" -X POST $B/claims/$ID/pay
s "assessor pays" "$AA" -X POST $B/claims/$ID/pay
s "manager pays (Idempotency-Key demo-1)" "$MA" -X POST -H "Idempotency-Key: demo-1" $B/claims/$ID/pay
s "replay without key" "$MA" -X POST $B/claims/$ID/pay
s "replay with same key" "$MA" -X POST -H "Idempotency-Key: demo-1" $B/claims/$ID/pay
s "replay with other key" "$MA" -X POST -H "Idempotency-Key: demo-2" $B/claims/$ID/pay
s "customer payout view" "$CA" $B/claims/$ID/payout
echo "== Audit trail for this claim"
npx wrangler d1 execute easy-claim-db --local --command "SELECT action, actor_role, outcome, json_extract(details,'$.reason') AS reason, json_extract(details,'$.to') AS to_stage FROM audit_events WHERE resource_id = '$ID' OR json_extract(details,'$.claimId') = '$ID' ORDER BY occurred_at, rowid" 2>/dev/null | grep -E '"action"|"actor_role"|"outcome"|"reason"|"to_stage"' | paste - - - - - | sed 's/[[:space:]]\+/ /g'
echo "== Ledger rows"
npx wrangler d1 execute easy-claim-db --local --command "SELECT outcome, approved_amount_cents, claimed_amount_cents, actor_id, rules_version FROM claim_decisions WHERE claim_id = '$ID'; SELECT amount_cents, destination_last4, status, idempotency_key, initiated_by FROM payouts WHERE claim_id = '$ID'" 2>/dev/null | grep -E '"(outcome|approved_amount_cents|claimed_amount_cents|actor_id|rules_version|amount_cents|destination_last4|status|idempotency_key|initiated_by)"' | paste - - - - - | sed 's/[[:space:]]\+/ /g'
