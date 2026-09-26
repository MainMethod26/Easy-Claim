#!/usr/bin/env bash
# Phase 5 live demo: ML-DSA-65 decision integrity against wrangler dev (127.0.0.1:8789).
# Usage: bash live-demo-p5.sh part1   (server running)      -> creates and signs a decision, verifies VALID
#        (stop the server) bash live-demo-p5.sh tamper       -> insider edits the approved amount directly in D1
#        (start the server) bash live-demo-p5.sh part2       -> verify TAMPERED, payout refused
set -u
cd "$(dirname "$0")/../../.."
B=http://127.0.0.1:8789/api/v1
CT="Content-Type: application/json"
STATE=.wrangler/p5-demo-claim
mint() { node scripts/mint-token.mjs "$@"; }
CA=$(mint --sub user123 --role CUSTOMER)
AA=$(mint --sub assessor_a1 --role ASSESSOR --tenant ins_discovery)
MA=$(mint --sub manager_a1 --role MANAGER --tenant ins_discovery)
s() { local label=$1 token=$2; shift 2; printf '[%s] %s\n' "$label" "$(curl -s -m 60 -w ' -> HTTP %{http_code}' -H "Authorization: Bearer $token" "$@" | cut -c1-300)"; }

case "${1:-}" in
part1)
  ID=$(curl -s -m 60 -X POST -H "Authorization: Bearer $CA" -H "$CT" -d '{"policyId":"pol_disc_001","category":"Medical"}' $B/claims/initiate | node -pe 'JSON.parse(require("fs").readFileSync(0)).claimId')
  echo "$ID" > "$STATE"; echo "[claim] $ID"
  s "payout details R4 200" "$CA" -X PUT -H "$CT" -d '{"claimedAmountCents":420000,"bankName":"Demo Bank","accountHolder":"Customer A","accountNumber":"62001234567890"}' $B/claims/$ID/payout-details
  s "screening" "$CA" -X PATCH -H "$CT" -d '{"causeOfLoss":"Hospital admission","incidentDate":"2026-01-10"}' $B/claims/$ID/screening
  s "submit" "$CA" -X POST $B/claims/$ID/submit
  for step in verify screen review; do s "$step" "$AA" -X POST $B/claims/$ID/$step; done
  echo "== Manager decides: the decision is signed with ML-DSA-65"
  s "decide Approved" "$MA" -X POST -H "$CT" -d '{"outcome":"Approved","reason":"Documents verified, within cover"}' $B/claims/$ID/decide
  echo "== Anyone authorised can verify it; the public key is published"
  s "verify" "$CA" $B/claims/$ID/decision/verify
  s "public key (truncated)" "$AA" $B/integrity/public-key
  ;;
tamper)
  ID=$(cat "$STATE")
  echo "== Insider with raw DB access drops the append-only trigger and raises the approved amount to R420 000"
  npx wrangler d1 execute easy-claim-db --local --command "DROP TRIGGER IF EXISTS claim_decisions_no_update; UPDATE claim_decisions SET approved_amount_cents = 42000000 WHERE claim_id = '$ID'" 2>/dev/null | grep -E '"changes"' | head -2
  ;;
part2)
  ID=$(cat "$STATE")
  echo "== After tampering"
  s "verify" "$MA" $B/claims/$ID/decision/verify
  s "pay" "$MA" -X POST $B/claims/$ID/pay
  ;;
*) echo "usage: $0 part1|tamper|part2"; exit 1 ;;
esac
