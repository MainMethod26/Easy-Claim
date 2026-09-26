#!/usr/bin/env bash
# Phase 4 completion live demo against wrangler dev (127.0.0.1:8789).
# Prereqs (before starting the server): npm run db:migrate:local && npm run db:seed:local &&
#   npm run signals:import:local && npm run demo:quantum:local
set -u
cd "$(dirname "$0")/../../.."
B=http://127.0.0.1:8789/api/v1
CT="Content-Type: application/json"
mint() { node scripts/mint-token.mjs "$@"; }
CA=$(mint --sub user123 --role CUSTOMER)
AA=$(mint --sub assessor_a1 --role ASSESSOR --tenant ins_discovery)
MA=$(mint --sub manager_a1 --role MANAGER --tenant ins_discovery)
AB=$(mint --sub assessor_b1 --role ASSESSOR --tenant ins_sanlam)
s() { local label=$1 token=$2; shift 2
  if [ "$token" = "-" ]; then out=$(curl -s -m 60 -w ' -> HTTP %{http_code}' "$@"); else out=$(curl -s -m 60 -w ' -> HTTP %{http_code}' -H "Authorization: Bearer $token" "$@"); fi
  printf '[%s] %s\n' "$label" "$(printf '%s' "$out" | cut -c1-260)"; }

echo "== DEMO 1: normal claim → Screening (classical + quantum signal attached, STANDARD_REVIEW)"
s "screen claim_demo_normal" "$AA" -X POST $B/claims/claim_demo_normal/screen
echo "== DEMO 2: unusual claim → Screening (HIGH, REVIEW_REQUIRED) — a signal, not a verdict"
s "screen claim_demo_unusual" "$AA" -X POST $B/claims/claim_demo_unusual/screen
echo "== Attack 1: fake score in the request body"
s "risk-signals read" "$MA" $B/claims/claim_demo_unusual/risk-signals
s "POST risk-signals quantumScore=0" "$MA" -X POST -H "$CT" -d '{"quantumScore":0}' $B/claims/claim_demo_unusual/risk-signals
echo "== Attack 2/3: other customer / other tenant / no token"
s "customer reads signal" "$CA" $B/claims/claim_demo_unusual/risk-signals
s "tenant B assessor reads signal" "$AB" $B/claims/claim_demo_unusual/risk-signals
s "no token" - $B/claims/claim_demo_unusual/risk-signals
echo "== Attack 5: quantum → outcome bypass (straight from Screening)"
s "pay from Screening" "$MA" -X POST $B/claims/claim_demo_unusual/pay
s "decide from Screening" "$MA" -X POST -H "$CT" -d '{"outcome":"Rejected","reason":"high anomaly"}' $B/claims/claim_demo_unusual/decide
s "decide with client score" "$MA" -X POST -H "$CT" -d '{"outcome":"Rejected","reason":"x","quantumScore":1}' $B/claims/claim_demo_unusual/decide
echo "== Human path: review → human decision (records the signal it saw)"
s "review" "$AA" -X POST $B/claims/claim_demo_unusual/review
s "manager decides (Rejected, own reasoning)" "$MA" -X POST -H "$CT" -d '{"outcome":"Rejected","reason":"Reported 300+ days after the incident; outside policy notification terms"}' $B/claims/claim_demo_unusual/decide
s "decision view" "$MA" $B/claims/claim_demo_unusual/decision
