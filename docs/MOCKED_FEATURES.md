# Mocked & Stubbed Features

Based on the project documentation and codebase as of the current phase, the following features are currently **not real** (mocked, stubbed, or not yet implemented):

### 1. Payouts (Simulated)
The payout endpoint (`/pay`) is completely simulated. While it correctly checks roles (only Managers can pay, not Assessors) and records the approved amount, it does **not** integrate with any real payment rail or bank to execute actual transactions.

### 2. Profile & Identity
All user profile endpoints (`GET /profile`, `PATCH /profile`, `/consent`, `/mandates`) are just returning empty stubs or hard-coded JSON responses (like `{ consent: true }` or `{ updated: true }`). They don't read from or save to the database yet.

### 3. Dashboard, Notifications & Activity
- **Dashboard & Shortcuts:** The homepage banner and shortcuts return hard-coded demo data.
- **Notifications:** The notifications endpoint returns static demo data and isn't even scoped to the logged-in user yet.
- **Activity & History:** The `/activities/history` and `/activities/audit-trail` endpoints are currently empty stubs that do not read from the actual audit logs or activity database.

### 4. Evidence Upload & OCR (Document Scanning)
- Document uploads (`/evidence-ocr`) don't actually save files to storage yet (the API just pretends to accept them and queues a mock event).
- The OCR (text extraction) service is just a stub that logs the request but does no actual document scanning.

### 5. Insurer Portal (Missing UI)
The backend has full support for Insurer roles (Assessors, Managers, Admins) and a multi-tenant system to handle different insurance companies (Discovery, Sanlam, OUTsurance, etc.). However, there is currently **no frontend UI** built for insurers to log in and process claims.

### 6. Authentication Architecture
There is no real identity provider (like Auth0 or Firebase). The backend issues local-only JWT tokens signed with a development secret. Features like token revocation (logging users out across devices) and security key rotation are planned but not yet implemented. Furthermore, the frontend currently has a bug where the generated token is discarded immediately after login.
