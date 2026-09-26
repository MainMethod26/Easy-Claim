#!/usr/bin/env bash
# Live end-to-end demo + attack checks (three-role model) against a running local Worker (cd backend && npm run dev).
# Usage (from the repo root):  bash docs/integration/live-demo.sh [baseUrl]
# Signs in with the seeded demo accounts (password: DEMO_LOGIN_PASSWORD in backend/.dev.vars); never prints it or any token.
# Roles: CUSTOMER (mike, lerato), ASSESSOR/MANAGER (assessor_*/manager_*), INSURER_ADMIN (admin_*), SUPERADMIN (superadmin).
set -u
BASE="${1:-http://127.0.0.1:8787}/api/v1"
PW="$(grep '^DEMO_LOGIN_PASSWORD=' backend/.dev.vars | cut -d= -f2-)"
PASS=0; FAIL=0

j() { node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const o=JSON.parse(s);const v=$1;console.log(typeof v==='object'?JSON.stringify(v):v)}catch(e){console.log('<non-json>')}})"; }
# req METHOD PATH TOKEN [JSON] [extra curl args...] -> prints "STATUS BODY"
req() {
  local m=$1 p=$2 t=$3 d=${4:-}; shift 4 2>/dev/null || shift $#
  local args=(-s -o /tmp/ec_body -w '%{http_code}' -X "$m" "$BASE$p")
  [ -n "$t" ] && args+=(-H "Authorization: Bearer $t")
  [ -n "$d" ] && args+=(-H 'Content-Type: application/json' --data "$d")
  local code; code=$(curl "${args[@]}" "$@"); echo "$code $(cat /tmp/ec_body)"
}
check() { # check LABEL EXPECTED ACTUAL
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf 'PASS  %-72s %s\n' "$1" "$3"; else FAIL=$((FAIL+1)); printf 'FAIL  %-72s expected %s got %s\n' "$1" "$2" "$3"; fi
}
login() { req POST /auth/login "" "{\"username\":\"$1\",\"password\":\"$PW\"}" | cut -d' ' -f2- | j 'o.token'; }

echo "== EasyClaim live demo against $BASE ($(date -u +%FT%TZ))"
CUST=$(login mike); CUSTB=$(login lerato); ASSA=$(login assessor_discovery); MANA=$(login manager_discovery); ASSB=$(login assessor_sanlam)
ADMA=$(login admin_discovery); ADMB=$(login admin_sanlam); SUPER=$(login superadmin)
[ ${#CUST} -gt 100 ] && [ ${#ASSA} -gt 100 ] && [ ${#MANA} -gt 100 ] && [ ${#ADMA} -gt 100 ] && [ ${#SUPER} -gt 100 ] && echo "signed in 8 demo accounts (tokens not shown)" || { echo "login failed: is the Worker running and were the demo users seeded (npm run db:seed:users:local)?"; exit 1; }

echo; echo "-- Security checks"
check "ATTACK-01 no token -> 401"                                   401 "$(req GET /claims "" | cut -c1-3)"
check "old open login /profile/login {email:manager} -> 401"         401 "$(req POST /profile/login "" '{"email":"manager"}' | cut -c1-3)"
check "login with a wrong password -> 401"                          401 "$(req POST /auth/login "" '{"username":"mike","password":"wrong-password"}' | cut -c1-3)"
check "login as an unknown user -> 401 (same body)"                 401 "$(req POST /auth/login "" "{\"username\":\"manager\",\"password\":\"$PW\"}" | cut -c1-3)"
check "login with client-chosen role -> 400"                        400 "$(req POST /auth/login "" "{\"username\":\"mike\",\"password\":\"$PW\",\"role\":\"SUPERADMIN\"}" | cut -c1-3)"
check "register cannot choose a role -> 400"                        400 "$(req POST /auth/register "" '{"username":"eve","password":"1234567","displayName":"Eve","role":"SUPERADMIN"}' | cut -c1-3)"
check "ATTACK-21 superadmin cannot verify a claim -> 403"           403 "$(req POST /claims/claim_mom_103/verify "$SUPER" | cut -c1-3)"
check "ATTACK-21 superadmin cannot pay -> 403"                      403 "$(req POST /claims/claim_sanlam_102/pay "$SUPER" | cut -c1-3)"
check "superadmin reads the platform claim list -> 200"             200 "$(req GET /claims "$SUPER" | cut -c1-3)"
check "customer cannot open /admin -> 403"                          403 "$(req GET /admin/tenants "$CUST" | cut -c1-3)"
check "insurer admin cannot open /admin -> 403"                     403 "$(req GET /admin/stats "$ADMA" | cut -c1-3)"
check "assessor cannot open /tenant -> 403"                         403 "$(req GET /tenant/users "$ASSA" | cut -c1-3)"
check "ATTACK-22 Sanlam admin cannot disable a Discovery admin -> 404" 404 "$(req PATCH /tenant/users/usr_admin_discovery "$ADMB" '{"status":"disabled"}' | cut -c1-3)"
check "ATTACK-24 insurer admin cannot verify a claim -> 403"        403 "$(req POST /claims/claim_disc_101/request-info "$ADMA" | cut -c1-3)"
check "insurer admin reads its own claims read-only -> 200"         200 "$(req GET /claims/claim_disc_101 "$ADMA" | cut -c1-3)"
check "ATTACK-02 forged token -> 401"                               401 "$(req GET /claims "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJtYW5hZ2VyX2ExIn0.AAAA" | cut -c1-3)"
check "ATTACK-06 customer calls assessor action -> 403"             403 "$(req POST /claims/claim_mom_103/verify "$CUST" | cut -c1-3)"
check "ATTACK-04 customer B reads customer A claim -> 404"          404 "$(req GET /claims/claim_disc_101 "$CUSTB" | cut -c1-3)"
check "ATTACK-05 Sanlam assessor reads Discovery claim -> 404"      404 "$(req GET /claims/claim_disc_101 "$ASSB" | cut -c1-3)"
check "ATTACK-08 X-User-Id spoof ignored -> 404"                    404 "$(req GET /claims/claim_disc_101 "$CUSTB" "" -H 'X-User-Id: user123' | cut -c1-3)"
check "ATTACK-10 X-Tenant-Id spoof ignored -> 404"                  404 "$(req GET /claims/claim_disc_101 "$ASSB" "" -H 'X-Tenant-Id: ins_discovery' | cut -c1-3)"
check "ATTACK-09 role in request body -> 400"                       400 "$(req POST /claims/initiate "$CUST" '{"policyId":"pol_disc_001","role":"SUPERADMIN"}' | cut -c1-3)"

echo; echo "-- Customer journey (new claim)"
R=$(req POST /claims/initiate "$CUST" '{"policyId":"pol_disc_001","category":"Property"}'); check "initiate -> 201" 201 "${R:0:3}"
CID=$(echo "${R:4}" | j 'o.claimId'); echo "      claimId $CID"
check "describe loss -> 200"      200 "$(req PATCH /claims/$CID/screening "$CUST" '{"causeOfLoss":"Phone stolen at a taxi rank. SAPS case 123/09/2026.","incidentDate":"2026-09-20"}' | cut -c1-3)"
check "payout details -> 200"     200 "$(req PUT /claims/$CID/payout-details "$CUST" '{"claimedAmountCents":420000,"bankName":"Demo Bank","accountHolder":"Thabo Mokoena","accountNumber":"62001234567890"}' | cut -c1-3)"
# curl on Windows needs a native path inside -F "file=@..." (Git Bash does not translate it).
TMPD="$(mktemp -d)"; winpath() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else echo "$1"; fi; }
printf '%%PDF-1.4\n%% EasyClaim live demo receipt\n' > "$TMPD/receipt.pdf"
printf 'MZ fake exe' > "$TMPD/fake.pdf"
RECEIPT="$(winpath "$TMPD/receipt.pdf")"; FAKE="$(winpath "$TMPD/fake.pdf")"
check "upload evidence (PDF) -> 201" 201 "$(req POST /claims/$CID/evidence "$CUST" "" -F "file=@$RECEIPT;type=application/pdf" | cut -c1-3)"
check "upload .exe renamed .pdf -> 415" 415 "$(req POST /claims/$CID/evidence "$CUST" "" -F "file=@$FAKE;type=application/pdf" | cut -c1-3)"
check "submit -> 200"             200 "$(req POST /claims/$CID/submit "$CUST" | cut -c1-3)"
check "ATTACK-14 pay a Submitted claim -> 409" 409 "$(req POST /claims/$CID/pay "$MANA" | cut -c1-3)"
check "evidence locked after submit -> 409" 409 "$(req POST /claims/$CID/evidence "$CUST" "" -F "file=@$RECEIPT;type=application/pdf" | cut -c1-3)"
check "assessor sees 1 evidence file" 1 "$(req GET /claims/$CID/evidence "$ASSA" | cut -d' ' -f2- | j 'o.evidence.length')"

echo; echo "-- Insurer journey (assessor then manager) on the HIGH_ANOMALY demo claim (claim_demo_unusual, stage Verified)"
R=$(req POST /claims/claim_demo_unusual/screen "$ASSA"); check "screen -> 200" 200 "${R:0:3}"
check "signal band"            HIGH             "$(echo "${R:4}" | j 'o.riskSignals.anomalyBand')"
check "recommendation"         REVIEW_REQUIRED  "$(echo "${R:4}" | j 'o.riskSignals.screeningRecommendation')"
check "advisory"               true             "$(echo "${R:4}" | j 'o.riskSignals.advisory')"
check "HIGH did not reject: stage" Screening    "$(req GET /claims/claim_demo_unusual "$ASSA" | cut -d' ' -f2- | j 'o.claim.stage')"
check "customer cannot read the signal -> 403" 403 "$(req GET /claims/claim_demo_unusual/risk-signals "$CUST" | cut -c1-3)"
check "ATTACK-11 fake score in /screen body ignored (already Screening -> 409)" 409 "$(req POST /claims/claim_demo_unusual/screen "$ASSA" '{"quantumAnomaly":0,"anomalyBand":"NORMAL"}' | cut -c1-3)"
check "review -> 200"                        200 "$(req POST /claims/claim_demo_unusual/review "$ASSA" | cut -c1-3)"
check "ATTACK-07 assessor decides -> 403"    403 "$(req POST /claims/claim_demo_unusual/decide "$ASSA" '{"outcome":"Approved","reason":"x"}' | cut -c1-3)"
check "ATTACK-07 superadmin decides -> 403"  403 "$(req POST /claims/claim_demo_unusual/decide "$SUPER" '{"outcome":"Approved","reason":"x"}' | cut -c1-3)"
check "ATTACK-24 insurer admin decides -> 403" 403 "$(req POST /claims/claim_demo_unusual/decide "$ADMA" '{"outcome":"Approved","reason":"x"}' | cut -c1-3)"
check "ATTACK-07 customer decides -> 403"    403 "$(req POST /claims/claim_demo_unusual/decide "$CUST" '{"outcome":"Approved","reason":"x"}' | cut -c1-3)"
check "ATTACK-12 client recommendation on decide -> 400" 400 "$(req POST /claims/claim_demo_unusual/decide "$MANA" '{"outcome":"Rejected","reason":"x","screeningRecommendation":"STANDARD_REVIEW"}' | cut -c1-3)"
R=$(req POST /claims/claim_demo_unusual/decide "$MANA" '{"outcome":"Rejected","reason":"Incident reported 323 days late; policy requires notice within 30 days"}')
check "manager decides (human decision) -> 200" 200 "${R:0:3}"
check "decision signed with"   ML-DSA-65        "$(echo "${R:4}" | j 'o.integrity.alg')"
check "customer verifies decision integrity" VALID "$(req GET /claims/claim_demo_unusual/decision/verify "$CUST" | cut -d' ' -f2- | j 'o.integrity.status')"

echo; echo "-- Approve + pay path on the NORMAL demo claim (claim_demo_normal)"
for s in screen review; do check "$s -> 200" 200 "$(req POST /claims/claim_demo_normal/$s "$ASSA" | cut -c1-3)"; done
check "approve without payout details -> 422" 422 "$(req POST /claims/claim_demo_normal/decide "$MANA" '{"outcome":"Approved","reason":"ok"}' | cut -c1-3)"
echo "      (demo claims carry no payout details, so approval is refused by design; the approve+pay path runs on the new claim below)"

echo; echo "-- Approve + pay path on the new customer claim $CID"
for s in verify screen review; do check "$s -> 200" 200 "$(req POST /claims/$CID/$s "$ASSA" | cut -c1-3)"; done
R=$(req POST /claims/$CID/decide "$MANA" '{"outcome":"Approved","reason":"Evidence verified, within cover"}'); check "approve -> 200" 200 "${R:0:3}"
check "approved amount (cents)" 420000 "$(echo "${R:4}" | j 'o.approvedAmountCents')"
check "decision integrity" VALID "$(req GET /claims/$CID/decision/verify "$CUST" | cut -d' ' -f2- | j 'o.integrity.status')"
check "ATTACK-13 amount in /pay body -> 400" 400 "$(req POST /claims/$CID/pay "$MANA" '{"amountCents":99999999}' | cut -c1-3)"
R=$(req POST /claims/$CID/pay "$MANA" "" -H 'Idempotency-Key: live-demo-1'); check "pay (simulated) -> 200" 200 "${R:0:3}"
check "paid amount (cents)" 420000 "$(echo "${R:4}" | j 'o.amountCents')"
check "ATTACK-18 replay same key -> 200 already_paid" already_paid "$(req POST /claims/$CID/pay "$MANA" "" -H 'Idempotency-Key: live-demo-1' | cut -d' ' -f2- | j 'o.status')"
check "ATTACK-18 new pay request -> 409" 409 "$(req POST /claims/$CID/pay "$MANA" | cut -c1-3)"
check "customer sees stage" Paid "$(req GET /claims/$CID "$CUST" | cut -d' ' -f2- | j 'o.claim.stage')"
check "ATTACK-19 duplicate decision -> 409" 409 "$(req POST /claims/$CID/decide "$MANA" '{"outcome":"Rejected","reason":"again"}' | cut -c1-3)"

echo; echo "-- Platform and tenant administration"
check "superadmin stats -> 200"                     200 "$(req GET /admin/stats "$SUPER" | cut -c1-3)"
check "superadmin sees the paid claim read-only"    Paid "$(req GET /claims/$CID "$SUPER" | cut -d' ' -f2- | j 'o.claim.stage')"
NEWT="ins_demo_$(date +%s)"
check "superadmin creates an insurer -> 201"        201 "$(req POST /admin/tenants "$SUPER" "{\"id\":\"$NEWT\",\"name\":\"Demo Mutual\"}" | cut -c1-3)"
check "superadmin creates its insurer admin -> 201" 201 "$(req POST /admin/users "$SUPER" "{\"username\":\"admin_$NEWT\",\"password\":\"$PW\",\"displayName\":\"Demo Mutual Admin\",\"role\":\"INSURER_ADMIN\",\"tenantId\":\"$NEWT\"}" | cut -c1-3)"
check "new insurer admin can sign in"               INSURER_ADMIN "$(req POST /auth/login "" "{\"username\":\"admin_$NEWT\",\"password\":\"$PW\"}" | cut -d' ' -f2- | j 'o.actor.role')"
NEWA="assessor_$(date +%s)"
check "insurer admin adds an assessor -> 201"       201 "$(req POST /tenant/users "$ADMA" "{\"username\":\"$NEWA\",\"password\":\"$PW\",\"displayName\":\"New Assessor\",\"role\":\"ASSESSOR\"}" | cut -c1-3)"
check "new assessor can sign in"                    ASSESSOR "$(req POST /auth/login "" "{\"username\":\"$NEWA\",\"password\":\"$PW\"}" | cut -d' ' -f2- | j 'o.actor.role')"
check "superadmin cannot create a superadmin -> 400" 400 "$(req POST /admin/users "$SUPER" "{\"username\":\"root2\",\"password\":\"$PW\",\"displayName\":\"Root\",\"role\":\"SUPERADMIN\"}" | cut -c1-3)"
check "insurer admin tenant stats -> 200"           200 "$(req GET /tenant/stats "$ADMA" | cut -c1-3)"

echo; echo "== $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
