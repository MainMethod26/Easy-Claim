# Demo runbook (local)

Everything runs on one laptop: the Worker with local D1/R2 (Miniflare) and the Flutter app. No cloud account needed.
Verified on Windows 11, Node 24, wrangler 4.141, Flutter 3.47.5 on 26 Sep 2026.

## 0. Prerequisites

- Node.js 20+ and npm. Flutter SDK (stable). For the quantum pipeline only: Python 3.11+.
- Keep the clone in a short path (e.g. `C:\dev\Easy-Claim`); very long Windows paths break `wrangler d1 --local`.
- **Port 8787 must be free.** On Windows a stale `workerd.exe` from another checkout can keep listening on 8787, and
  new requests then hang with no error. Check first:
  ```bash
  netstat -ano | grep ":8787"        # PowerShell: Get-NetTCPConnection -LocalPort 8787
  ```
  If something else is listening, stop it or run the Worker on another port (`npm run dev -- --port 8790`) and use
  that port in every URL below.

## 1. Backend: install, secrets, database

```bash
cd backend
npm install
npm run setup:local        # creates backend/.dev.vars: JWT_SECRET, MLDSA_SEED (random) and DEMO_LOGIN_PASSWORD=1234567
                           # an older .dev.vars? run: npm run setup:local -- --add-missing
npm run demo:setup:local   # migrations 0001..0009, seed, demo accounts, quantum screening signals, the NORMAL + HIGH demo claims
npm run dev                # http://127.0.0.1:8787 ; wait until `curl http://127.0.0.1:8787/api/v1/claims` answers 401
```

`backend/.dev.vars` sets `ENVIRONMENT=development`, which switches on `/swagger`. Demo accounts are seeded with the
`DEMO_LOGIN_PASSWORD` line of that file (agreed demo password `1234567`, local only).

Do not run `wrangler d1 execute` (e.g. `npm run demo:setup:local`) while `npm run dev` is running; stop the Worker
first. To reset the demo, stop the Worker and delete `backend/.wrangler/state`, then repeat `demo:setup:local`.

## 2. Frontend

```bash
cd frontend
flutter pub get
# Web (Chrome). 5173 is in ALLOWED_ORIGINS in .dev.vars; another port needs adding there.
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://127.0.0.1:8787/api/v1
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787/api/v1
# Insurer portal as a separate entry point (staff can also sign in through the normal app)
flutter run -d chrome --web-port 5174 -t lib/main_admin.dart --dart-define=API_BASE_URL=http://127.0.0.1:8787/api/v1
```
(5174 must be added to `ALLOWED_ORIGINS` for the second web app.)

## 3. Demo accounts (local only, password `1234567`)

| Username | Role | Insurer (tenant) | Use it for |
|---|---|---|---|
| `mike` | CUSTOMER (Mike) | – (policies at Discovery, Sanlam, Old Mutual) | the customer journey |
| `lerato`, `sipho` | CUSTOMER | – | "another customer" attacks |
| `assessor_discovery` | ASSESSOR | Discovery | verify, screen, review |
| `manager_discovery` | MANAGER | Discovery | decide, pay |
| `admin_discovery` | INSURER_ADMIN | Discovery | staff accounts, tenant stats, read-only claims |
| `assessor_sanlam`, `manager_sanlam`, `admin_sanlam` | same roles | Sanlam | cross-tenant attacks |
| `superadmin` | SUPERADMIN | – | insurers, insurer admins, platform stats, read-only claims |

Anyone can also register a new customer from the sign-in screen ("Create account").

## 4. The five-minute story

1. **Customer (`mike`)**: sign in → My Covers shows real policies → Submit Claim on the Discovery policy → category,
   eligibility check, describe the loss, claimed amount and bank details, attach a PDF/JPEG/PNG → submit. Claim shows
   as Submitted. (Optional: "Create account" to register a brand-new customer live.)
2. **Assessor (`assessor_discovery`)**: the queue shows the claim with its amount → Verify → Screen. The screening
   card shows the classical and quantum-kernel signals, the band and "Review required / Human decision required".
   Open `claim_demo_unusual` (seeded HIGH anomaly) and screen it: HIGH, and it is still just "Screening". → Review.
   The assessor sees "Manager decision required": no Decide or Pay button.
3. **Manager (`manager_discovery`)**: Record decision (Approve, reason, optional amount) → "✓ Cryptographically
   verified · ML-DSA-65" → Pay (simulated) → Paid. Reject the HIGH claim with a reason: a human decision, signed.
4. **Insurer admin (`admin_discovery`)**: Team tab: tenant stats, staff list, add an assessor, disable/enable. Claims
   tab is read-only, with no action buttons and no screening card.
5. **Superadmin (`superadmin`)**: platform dashboard (claims by stage per insurer, users by role) → Insurers: add
   "Demo Mutual" → Accounts: create its insurer admin → Claims: read-only list across insurers, open the paid claim.
   There is no Verify/Decide/Pay button anywhere for the superadmin.
6. **Customer again**: claim shows Paid, the decision and "Decision verified". No model internals.
7. **Security** (Postman folders 00, 5–8, 11, 12 or the script below): no token 401, wrong password 401 with the same
   body as an unknown user, a role in the login or register body 400, customer on an insurer action 403, assessor
   deciding or paying 403, insurer admin or superadmin on any claim action 403, other customer's claim 404, other insurer's claim or admin account 404, spoofed
   `X-User-Id`/`X-Role`/`X-Tenant-Id` ignored, fake risk score ignored/400, pay before decision 409, replayed payout 409.

## 4b. What each screen looks like

Screenshots from a full live run through the web app (`docs/integration/evidence/app/`):
`01_signin` · `02_customer_home` · `03_customer_covers` · `04`–`10` the seven wizard steps · `12_assessor_queue` ·
`14_assessor_screening_normal` · `16_assessor_screening_HIGH` · `18`/`19b` manager decision and integrity card ·
`20_manager_paid` · `21`/`22` the HIGH claim rejected by a human, signed · `24_customer_activity` the customer's Paid
view · `26_attack_login_manager_word` · `27_sanlam_queue`.

## 5. Scripted live check

```bash
# from the repo root, with the Worker running
bash docs/integration/live-demo.sh http://127.0.0.1:8787
```
It signs in the demo accounts, runs the customer and insurer journeys (including the HIGH_ANOMALY claim through
human review) and the attack checks. It prints PASS/FAIL per step and never prints tokens or the password.
Recorded run: [integration/evidence/LIVE_DEMO.log](integration/evidence/LIVE_DEMO.log).
The script moves the demo claims forward; reset the database (§1) before running it a second time.

Decision tampering is demonstrated by the tests (`backend/test/attackSuite.test.ts` ATTACK-16/17,
`decisionIntegrity.test.ts`), because it needs direct database edits while the Worker is stopped.

## 6. What to say (honesty lines)

- "The quantum-kernel signal is experimental and advisory. On our synthetic evaluation it did not beat the classical
  baseline, so EasyClaim never relies on it for a decision. A human decides."
- "ML-DSA-65 (NIST FIPS 204) signs every decision, so we can detect if signed decision data is later altered, and
  payout refuses a decision that no longer verifies." Not: "the database is immutable".
- "Accounts are real (hashed passwords, roles from the database). The demo password is shared for the demo only;
  an identity provider can replace the login later without changing any authorization code."
- "Assessors prepare, managers decide and pay, admins only manage accounts: nobody who creates accounts can approve money."
- Payouts are simulated. No money moves.
