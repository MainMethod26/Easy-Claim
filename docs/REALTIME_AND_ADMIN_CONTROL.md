# Live updates and insurer control (presentation notes)

EasyClaim connects two sides in real time: the **customer app** and the **insurer consoles** (assessor, manager and,
above all, the **insurer admin**). Whatever one side does appears on the other side's screen within about a second,
with no refresh.

## How it works (one paragraph for the judges)

Each audience has its own live channel: every customer has a private channel, every insurer has one shared
channel for its staff, and the platform operator has one. They run as Cloudflare Durable Objects that hold
WebSocket connections. When something changes, the backend sends a **signal** such as "consent signed on claim X",
with no names or other personal data. The app then fetches the details through the normal secured API. Every
permission check therefore stays in one place, and a leaked live message reveals nothing. The live connection is
opened with a 60-second ticket (never the login token in a URL). The connection also checks the website origin and
that the account is still active.

## Status indicators

| Indicator | Meaning | Where |
|---|---|---|
| **Awaiting POPIA mandate** | Form sent, customer has not opened it | Claim queues, claim screen, policy requests, admin overview |
| **Customer is reading** | Customer opened the form (first open is recorded, like DocuSign "viewed") | Same |
| **Mandate signed** | Signed with name + password, sealed ML-DSA-65 | Same; screening/approval unlock at once |
| **Mandate rejected** | Customer declined (optional reason shown) | Same; admin can send a new form |
| **Consent withdrawn** | Customer withdrew later (POPIA s11(2)(b)) | Same; further work locks at once |
| **Live / Offline** | The live connection itself | Header of the app and every console |

## Every interaction between the two sides

**POPIA consent and mandate**
1. Insurer sends a form (automatically when the assessor verifies the documents, or manually by the insurer
   admin). The customer immediately sees "Consent form to sign".
2. Customer opens it. The insurer sees **Customer is reading**.
3. Customer signs, declines or withdraws. The insurer's badge, counters and locked buttons change instantly.

**Onboarding (linking a policy)**
4. A new link request appears in the admin's queue, and the counter goes up.
5. The customer uploads a document. The admin sees it waiting to be checked.
6. The admin ticks a document as checked. The customer's checklist updates.
7. The admin asks for more information. The customer sees the question; their resubmission reaches the admin.
8. The admin approves or declines. The policy appears in the customer's Covers, or the reason is shown.

**Claims**
9. The customer submits, and the assessor's queue updates.
10. Each stage change moves the customer's timeline (Verified, Screening, Review, Decision, Paid).
11. Staff request information and the customer is told immediately. The customer's reply reaches staff immediately.
12. The claim's message thread works like chat in both directions.
13. Evidence uploads, appeals and withdrawals reach staff immediately.
14. The customer sees a decision and payment the moment they happen.

**The insurer admin in control**
15. **Disable an account, and that person's open app signs out immediately**, not at their next click and not when
    their session expires.
16. A declined or withdrawn mandate locks screening, review, decision and payment on every open staff screen.
17. **Live overview:**
    - "Needs attention" counters: awaiting mandate, customer reading, mandate rejected, consent withdrawn,
      info needed, new claims, pending policy requests;
    - a **live activity feed** of what customers and staff just did.
18. The admin sends and re-sends mandates and edits the insurer's own POPIA wording. They cannot approve or pay
    claims themselves (separation of duties).
19. The platform operator sees new insurer applications and account changes live.

## Similar real-world systems

- **DebiCheck (South African banks):** the bank sends a debit-order mandate, and the client approves or rejects
  it in their banking app. This is the same pattern as the POPIA mandate here.
- **DocuSign and other e-signature tools:** documents are tracked from sent to viewed to signed or declined, with a
  tamper-evident record.
- **FICA/KYC onboarding at banks:** the client uploads documents, the bank checks them, asks for more, then
  approves.
- **Medical-aid pre-authorisation:** a request goes in, the scheme decides live, and the member sees the outcome.
- **Loan and credit applications:** document checks, a consent to a credit check, and live status.
- **Telehealth consent:** the patient consents before a consultation, and the clinician sees it at once.

## Honest limits

- Live messages are signals only. If one is missed (for example on a bad network), the app catches up on
  reconnect, and every screen still has a manual refresh.
- Tickets live for 60 seconds and cannot be used as API tokens (and the reverse). A ticket is not single-use
  within its 60 seconds; the account is re-checked on every connect.
- Changing a password revokes other sessions at their next request. Only disabling an account also closes the
  live connection immediately.
