#!/usr/bin/env bash
# Phase 1 live attack evidence against the local wrangler dev server (127.0.0.1:8787).
set -u
cd /c/Users/HomePC/Music/Hackathon/Easy-Claim/backend
B=http://127.0.0.1:8787/api/v1
CT="Content-Type: application/json"

mint() { node scripts/mint-token.mjs "$@"; }
# raw signer for negative cases (expired, wrong key, wrong alg) using the real local secret
raw() { node --input-type=module -e "
import { sign } from 'hono/jwt';
import { readFileSync } from 'node:fs';
const dv = Object.fromEntries(readFileSync('.dev.vars','utf8').split('\n').filter(l=>l.includes('=')&&!l.startsWith('#')).map(l=>[l.slice(0,l.indexOf('=')).trim(), l.slice(l.indexOf('=')+1).trim()]));
const claims = JSON.parse(process.argv[1]); const secret = process.argv[2] === '-' ? dv.JWT_SECRET : process.argv[2]; const alg = process.argv[3] || 'HS256';
const now = Math.floor(Date.now()/1000);
const p = { iss: 'easyclaim-dev', aud: 'easyclaim-api', iat: now - 60, exp: now + 600, ...claims };
console.log(await sign(p, secret, alg));
" "$1" "${2:--}" "${3:-HS256}"; }
b64u() { node -e "process.stdout.write(Buffer.from(require('fs').readFileSync(0)).toString('base64url'))"; }

CA=$(mint --sub user123 --role CUSTOMER)
CB=$(mint --sub user456 --role CUSTOMER)
AA=$(mint --sub assessor_a1 --role ASSESSOR --tenant ins_discovery)
MA=$(mint --sub manager_a1 --role MANAGER --tenant ins_discovery)
AB=$(mint --sub assessor_b1 --role ASSESSOR --tenant ins_sanlam)
MB=$(mint --sub manager_b1 --role MANAGER --tenant ins_sanlam)
AD=$(mint --sub admin1 --role ADMIN)

# s LABEL TOKEN [curl args...]   (TOKEN may be "-" for no Authorization header)
s() {
  local label=$1 token=$2; shift 2
  local out
  if [ "$token" = "-" ]; then out=$(curl -s -m 20 -w ' -> HTTP %{http_code}' "$@")
  else out=$(curl -s -m 20 -w ' -> HTTP %{http_code}' -H "Authorization: Bearer $token" "$@"); fi
  printf '[%s] %s\n' "$label" "$(printf '%s' "$out" | cut -c1-170)"
}

NOW=$(date +%s)
echo "== ATTACK-P1-001 forged JWT (signed with a different secret)"
F=$(raw '{"sub":"manager_a1","role":"MANAGER","tenant_id":"ins_discovery"}' "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
s "forged" "$F" $B/claims
echo "== ATTACK-P1-002 expired JWT"
E=$(raw '{"sub":"user123","role":"CUSTOMER","exp":1}')
s "expired" "$E" $B/covers/my-covers
echo "== ATTACK-P1-003 wrong signature (last char altered)"
s "bad-sig" "${CA%?}x" $B/covers/my-covers
echo "== ATTACK-P1-004 role escalation by editing claims (payload replaced, original signature kept)"
H=$(printf '%s' "$CA" | cut -d. -f1); S=$(printf '%s' "$CA" | cut -d. -f3)
P=$(printf '{"sub":"user123","role":"MANAGER","tenant_id":"ins_discovery","iss":"easyclaim-dev","aud":"easyclaim-api","iat":%s,"exp":%s}' "$((NOW - 60))" "$((NOW + 600))" | b64u)
s "tampered" "$H.$P.$S" $B/claims
echo "== ATTACK-P1-004b alg=none"
# non-empty signature segment so the token passes the shape check and is rejected by the pinned alg in verify()
N="$(printf '{"alg":"none","typ":"JWT"}' | b64u).$P.AAAA"
s "alg-none" "$N" $B/claims
echo "== ATTACK-P1-004c HS512 token against pinned HS256"
H5=$(raw '{"sub":"user123","role":"CUSTOMER"}' - HS512)
s "hs512" "$H5" $B/covers/my-covers
echo "== ATTACK-P1-004d valid signature but lifetime above the 8h staff maximum"
L=$(raw "{\"sub\":\"manager_a1\",\"role\":\"MANAGER\",\"tenant_id\":\"ins_discovery\",\"exp\":$((NOW + 9*3600))}")
s "9h manager token" "$L" $B/claims
echo "== ATTACK-P1-005 tenant B assessor reads tenant A claim"
s "cross-tenant read" "$AB" $B/claims/claim_disc_101/timeline
s "non-existent claim (compare)" "$AB" $B/claims/claim_nope/timeline
echo "== ATTACK-P1-006 tenant B staff transition tenant A claim"
s "cross-tenant verify" "$AB" -X POST $B/claims/claim_disc_101/verify
s "cross-tenant decide" "$MB" -X POST -H "$CT" -d '{"outcome":"Approved"}' $B/claims/claim_disc_101/decide
s "stage unchanged? (owner reads)" "$CA" $B/claims/claim_disc_101/timeline
echo "== ATTACK-P1-007 customer calls insurer-only endpoints"
s "customer verify" "$CA" -X POST $B/claims/claim_disc_101/verify
s "customer decide" "$CA" -X POST -H "$CT" -d '{"outcome":"Approved"}' $B/claims/claim_disc_101/decide
s "customer ocr" "$CA" -X POST $B/ocr/process
echo "== ATTACK-P1-008 assessor attempts manager-only payout (own tenant, claim in Decision/Approved)"
s "assessor B pay" "$AB" -X POST $B/claims/claim_sanlam_102/pay
echo "== ATTACK-P1-009 token reuse after expiration (2 s token)"
T2=$(mint --sub user123 --role CUSTOMER --ttl 2)
s "fresh" "$T2" $B/claims/status
sleep 3
s "3s later" "$T2" $B/claims/status
echo "== ATTACK-P1-010 retired dev headers"
s "dev headers, no token" - -H "X-Dev-Actor-Id: user123" -H "X-Dev-Actor-Role: MANAGER" $B/claims
s "dev headers + valid customer token" "$CA" -X POST -H "X-Dev-Actor-Id: manager_a1" -H "X-Dev-Actor-Role: MANAGER" $B/claims/claim_disc_101/verify
echo "== ATTACK-P1-011 customer B reads customer A's claim (IDOR regression)"
s "IDOR" "$CB" $B/claims/claim_disc_101/timeline
echo "== ATTACK-P1-012 admin"
s "admin list" "$AD" $B/claims
s "admin timeline" "$AD" $B/claims/claim_disc_101/timeline
echo "== Tenant-scoped lists"
s "assessor A list" "$AA" "$B/claims?limit=50"
s "assessor B list" "$AB" "$B/claims?limit=50"
s "customer A list" "$CA" "$B/claims?limit=50"
echo "== Happy path: Submitted -> Paid with the right tenant and roles"
ID=$(curl -s -m 20 -X POST -H "Authorization: Bearer $CA" -H "$CT" -d '{"policyId":"pol_disc_001"}' $B/claims/initiate | node -pe 'JSON.parse(require("fs").readFileSync(0)).claimId')
echo "[initiate] $ID"
s "draft invisible to assessor A" "$AA" $B/claims/$ID/timeline
s "screening" "$CA" -X PATCH -H "$CT" -d '{"causeOfLoss":"Hospital admission","incidentDate":"2026-01-10"}' $B/claims/$ID/screening
s "submit" "$CA" -X POST $B/claims/$ID/submit
s "verify (assessor A)" "$AA" -X POST $B/claims/$ID/verify
s "screen (assessor A)" "$AA" -X POST $B/claims/$ID/screen
s "review (assessor A)" "$AA" -X POST $B/claims/$ID/review
s "pay before decision (manager A)" "$MA" -X POST $B/claims/$ID/pay
s "decide Approved (manager A)" "$MA" -X POST -H "$CT" -d '{"outcome":"Approved"}' $B/claims/$ID/decide
s "pay by assessor A" "$AA" -X POST $B/claims/$ID/pay
s "pay by manager A" "$MA" -X POST $B/claims/$ID/pay
s "pay again (replay)" "$MA" -X POST $B/claims/$ID/pay
s "customer timeline" "$CA" $B/claims/$ID/timeline
echo "== Audit rows for this run (last 10 minutes)"
npx wrangler d1 execute easy-claim-db --local --command "SELECT action, actor_role, actor_tenant_id, outcome, count(*) AS n FROM audit_events WHERE occurred_at > strftime('%Y-%m-%dT%H:%M:%fZ','now','-10 minutes') GROUP BY 1,2,3,4 ORDER BY 1" 2>/dev/null | grep -E '"action"|"actor_role"|"actor_tenant_id"|"outcome"|"n"' | paste - - - - - | sed 's/[[:space:]]\+/ /g'
