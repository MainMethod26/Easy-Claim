# Demo runbook

Two ways to demo: **live** on the team's Cloudflare account (nothing to install), or **local** on one laptop (Worker
with local D1/R2 via Miniflare plus the Flutter app). Updated 27 Sep 2026 (migrations 0001-0016).

## Live (team Cloudflare account)

| What | URL |
|---|---|
| App (customers and all staff roles, one app routed by role) | https://easy-claim-frontend.pages.dev |
| React insurer portal (assessor / manager view, real sign-in form) | https://easy-claim-admin-frontend.pages.dev |
| API | `https://<worker>.workers.dev/api/v1` (see `backend/wrangler.toml`) |

The live build lists the demo accounts on the sign-in screen (`--dart-define=SHOW_DEMO_ACCOUNTS=true`); the demo
password is `1234567` for every account in section 3. `claim_demo_normal` has already been approved and paid on
live; `claim_demo_unusual` (HIGH anomaly) is left open for the demo. File a fresh claim as `mike` to show the full path.

**Deploying** (team account `077883a9c8271d3b7bc8b28d6756cf9f`; D1 database `easy-claim-db` is the v2 database):

```bash
cd backend
npm run deploy:live        # typecheck, apply pending remote migrations, wrangler deploy
cd ../frontend
flutter build web --release --dart-define=API_BASE_URL=<api url> --dart-define=SHOW_DEMO_ACCOUNTS=true
CLOUDFLARE_ACCOUNT_ID=077883a9c8271d3b7bc8b28d6756cf9f npx wrangler pages deploy build/web --project-name easy-claim-frontend
```
Pushing to GitHub does **not** deploy anything; the Pages projects are direct uploads. Always deploy with the
committed `wrangler.toml` (older copies point at a deleted database). Secrets (`JWT_SECRET`, `MLDSA_SEED`, `PII_KEY`,
`DEMO_LOGIN_PASSWORD`) live only in Cloudflare; never print or commit them.

# Local

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
npm run setup:local        # creates backend/.dev.vars: JWT_SECRET, MLDSA_SEED, PII_KEY (random), DEMO_LOGIN_PASSWORD=1234567
                           # an older .dev.vars? run: npm run setup:local -- --add-missing
npm run demo:setup:local   # migrations 0001..0016, seed, demo accounts, quantum screening signals, the NORMAL + HIGH demo claims (with payout details)
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

## Live side-by-side demo (realtime)

Open two browser windows next to each other (one normal, one private, so both stay signed in):
left `admin_discovery` (or `assessor_discovery`), right `mike`. Both headers show a green **Live** dot.

1. Left (assessor): open a Submitted claim → Verify. Right: "Your insurer sent a POPIA consent form" appears at once.
2. Right: open the form. Left: the badge turns **Customer is reading**.
3. Right: sign (name + password). Left: **Mandate signed**, and Screening unlocks without a refresh.
   Or decline. Left: **Mandate rejected**; the insurer admin presses "Send a new consent form" and it appears on the right.
4. Left (insurer admin → Overview): the "Needs attention" counters and the live activity feed move with every step.
5. Messages on the claim thread appear on the other side like chat.
6. Admin control: as `admin_discovery` → Team → Disable an assessor who is signed in elsewhere. That app signs out
   at once with "Your access was changed by your administrator."

Full list of live interactions and similar real-world systems: [REALTIME_AND_ADMIN_CONTROL.md](REALTIME_AND_ADMIN_CONTROL.md).

## 3. Demo accounts (password `1234567`, local and live)

| Username | Role | Insurer (tenant) | Use it for |
|---|---|---|---|
| `mike` | CUSTOMER (Mike) | – (policies at Discovery, Sanlam, Old Mutual) | the customer journey |
| `lerato`, `sipho` | CUSTOMER | – | "another customer" attacks |
| `assessor_discovery` | ASSESSOR | Discovery | verify, screen, review |
| `manager_discovery` | MANAGER | Discovery | decide, pay |
| `admin_discovery` | INSURER_ADMIN | Discovery | staff, policy requests, required documents, audit, read-only claims |
| `assessor_sanlam`, `manager_sanlam`, `admin_sanlam` | same roles | Sanlam | cross-tenant attacks |
| `superadmin` | SUPERADMIN | – | insurer applications, insurers, insurer admins, security and integrity views. **No claim access** |

Anyone can also register a new customer from the sign-in screen ("Create account").

## 4. The five-minute story

1. **Customer (`mike`)**: sign in → My Covers shows real policies → Submit Claim on the Discovery policy → category,
   eligibility check, describe the loss, claimed amount and bank details, attach a PDF/JPEG/PNG → submit. Claim shows
   as Submitted. A claim left as Draft shows "Continue" and reopens the wizard where it stopped. (Optional: "Create
   account" to register a brand-new customer; Home shows a "Get set up" checklist: My details → EasyClaim ID → Link a
   policy.)
2. **Assessor (`assessor_discovery`)**: the queue shows the claim with its amount → Verify → Screen. The screening
   card shows the classical and quantum-kernel signals, the band and "Review required / Human decision required".
   Open `claim_demo_unusual` (seeded HIGH anomaly) and screen it: HIGH, and it is still just "Screening". → Review.
   **POPIA consent:** Verify means "documents checked", and it sends `mike` the insurer's consent / claim mandate form.
   Screen stays locked ("Waiting for the customer to sign") until `mike` opens the claim (or the Home banner), reads
   the form, ticks "I agree", types his name and password and signs. The form is sealed with ML-DSA-65 and staff see
   "Signed · Sealed". The seeded demo claims start at Verified without a form: press "Send consent form" first.
   `mike` can withdraw consent later (Profile → Consent forms); the claim then stops until a new form is signed.
   The assessor sees "Manager decision required": no Decide or Pay button. Evidence rows open the file itself.
   **Hand-off:** "Request information" asks for a message and moves the claim to Info Needed. As `mike`, the claim
   shows the insurer's message with "Upload more" and "Reply"; sending the reply moves it back to Screening. Both sides
   see the same message thread on the claim (Help → "Message your insurer" leads there too). The customer can also
   Withdraw (with a reason) or, after a rejection, Appeal; the reason is shown to staff.
3. **Manager (`manager_discovery`)**: Record decision (Approve, reason, optional amount) → "✓ Cryptographically
   verified · ML-DSA-65" → Pay (simulated, asks for confirmation) → Paid. Reject the HIGH claim with a reason: a
   human decision, signed. The manager's queue holds only Review and Appeal claims.
4. **Insurer admin (`admin_discovery`)**: Team: staff list, add an assessor, disable/enable (disabling signs that
   person out at once). Claims is read-only, with no action buttons and no screening card. Policy requests, Required
   docs and Audit log are described in 5d-5e.
5. **Superadmin (`superadmin`)**: Overview (claim counts by stage per insurer, users by role) → Applications →
   Insurers → Insurer admins → Security → Integrity → Audit log. There is no Claims tab and no claim action: the
   superadmin manages insurers and their admins only.
   **Consoles** (one app, chosen by role after sign-in): the insurer admin gets Overview (KPIs, claims by stage,
   screening bands, decision signatures), Claims (read-only), Policy requests, Required docs, Team and Audit log. The
   superadmin gets Overview, Applications, Insurers, Insurer admins, Security, Integrity and Audit log. Assessors
   (Submitted, Verified, Screening) and managers (Review, Appeal) get "My queue" and All claims. Every number is defined in
   `docs/admin/METRICS.md`; screenshots are in `docs/admin/screenshots/`.
   **Onboarding a new insurer and customer (27 Sep 2026):**
   a. On the sign-in screen, "Are you an insurer? Register your company". Fill in company, FSP number, contact
      email and the first admin's name, username and password.
   b. `superadmin` → Applications → Approve (choose the insurer id, e.g. `ins_hollard`). This creates the insurer
      and its admin; the applicant signs in with the password they chose.
   c. The new insurer admin → Team → add an assessor and a manager.
   d. A newly registered customer → Covers → Link a policy. Their EasyClaim ID is at the top. Add "My details"
      (name, email, phone, date of birth, SA ID number), tick one or more insurers, enter each policy number, send,
      then upload each insurer's required documents (ID document, proof of address, policy schedule by default).
   e. The insurer admin → Policy requests → open the request: client details (ID masked; "Reveal" is recorded),
      open each document and tick "Checked". Approve unlocks only when every required document is checked; or
      "Ask for more" (goes back to the customer) or Decline. With every document checked, "Send consent form" sends
      the insurer's POPIA consent form; Approve unlocks only once the customer has signed it. Search any client with their EasyClaim ID, and change
      the insurer's list under "Required docs".
      Approve (enter the plan name). The policy appears under the
      customer's covers, and the normal claim journey (steps 1–3) works on it.
   f. The insurer admin → Consent forms: edit the insurer's own onboarding and claim consent wording (placeholders
      such as `{{insurer}}` are filled in). Until it is saved, the EasyClaim POPIA starter text is used. Each save is
      a new version; forms already sent keep the text the customer saw.
   The superadmin never sees claims: `/claims` is 403 and every claim URL is 404 for it.
6. **Customer again**: claim shows Paid, the decision and "Decision verified". No model internals.
7. **Security** (Postman folders 00, 5–8, 11, 12 or the script below; tokens are re-checked against the account on
   every request, five wrong passwords lock an account for 15 minutes): no token 401, wrong password 401 with the same
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
