# EasyClaim Secure Software Development Life Cycle (SSDLC)

How security is built into every stage of EasyClaim's development, written against what the repository
actually contains on `main` (2026-09-26). Status words: **IMPLEMENTED** (in code, tested) · **PARTIAL** ·
**PLANNED** (designed, not built) · **DECISION REQUIRED** (product/security owner must decide).
Reference frameworks: NIST SSDF (SP 800-218), OWASP ASVS, OWASP API Security Top 10 (2023), POPIA. They are
assessment references, not compliance claims.

Channels: today the only interface is the HTTPS API (`/api/v1/*`) and the Flutter app. **The web
dashboard and Home Affairs eKYC are intended channels and do not exist in code yet**; where they are
mentioned below the controls are PLANNED and the design constraint is stated so they cannot bypass the
existing gates when they arrive.

---

## 1. Security requirements and risk assessment

### 1.1 Data classification

| Class | Data | Where it lives | Handling rule (status) |
|---|---|---|---|
| **High** | SA ID numbers, bank account numbers, account holder names, full evidence files (medical/ID documents, photos), signing secret | `claims.payout_*`, `evidence` objects in private R2, `JWT_SECRET` | Account number never stored: SHA-256 + last 4 only (IMPLEMENTED). Evidence in a private bucket, server-generated keys, no public URL (IMPLEMENTED). Secret only as a Cloudflare secret / `.dev.vars`, never in git (IMPLEMENTED). ID numbers: no field exists yet; when identity verification arrives they must be hashed or tokenised, never logged (PLANNED). |
| **Medium** | Claim narrative (cause of loss, incident date), decision reasons, claimed/approved amounts, evidence metadata (name, type, size, hash) | `claims`, `claim_decisions`, `evidence` | Owner or claim's tenant only; never in audit `details` (IMPLEMENTED). |
| **Low** | Claim stage/status, timestamps, audit metadata (actor id, role, tenant, action, reason codes) | `claims.stage/status`, `audit_events` | Tenant-scoped reads; audit rows append-only (IMPLEMENTED). |

### 1.2 Security requirements (must hold for every feature)

1. Every request is authenticated with a verified credential; no header, query or body value identifies a user (IMPLEMENTED: `src/security/actor.ts`).
2. Authorization is server-side and object-level: owner or tenant, never role alone (IMPLEMENTED: `loadAuthorizedClaim`).
3. One insurer's data is never visible to another, and a denied object is indistinguishable from a missing one (IMPLEMENTED: 404 on deny + audit).
4. The client never sets privileged state: stage, status, amounts, tenant, owner, decision (IMPLEMENTED: strict schemas + state machine).
5. Every state change and every refusal leaves an append-only audit row with who / what / when / which object / result (IMPLEMENTED).
6. Money-relevant records (decisions, payouts) are insert-only and reconstructable (IMPLEMENTED: `migrations/0005`).
7. Uploaded files and AI/OCR output are untrusted data, never instructions and never a transition (IMPLEMENTED for uploads; OCR PLANNED).
8. Secrets, tokens and high-class PII are never logged (IMPLEMENTED: only error class names / reason codes are logged; tested).
9. POPIA: collect the minimum, purpose-bound, with consent; data subjects can see their own data (PARTIAL: `/profile/consent` is a stub — DECISION REQUIRED on consent model and retention periods).

### 1.3 Risk register (top items)

| Risk | Likelihood / impact | Current control | Residual |
|---|---|---|---|
| Cross-tenant claim/evidence disclosure | Med / High | tenant boundary on every claim and evidence read, tested | low |
| Payout diversion (destination or amount change) | Med / High | destination frozen after submission, decision snapshot, server-held amount, one payout per claim | simulated payout only; real rail PLANNED |
| Stolen/forged token | Med / High | HS256 pinned, iss/aud/exp/iat, 8 h staff / 24 h customer TTL | no revocation, shared secret — IdP PLANNED (`BACKEND-SEC-019`) |
| Malicious upload | High / Med | type allowlist + magic bytes + 10 MB + private storage + hash | no malware scanning (PLANNED) |
| Audit/decision tampering by insider with DB access | Low / High | append-only triggers | triggers droppable by DB admin; ML-DSA signing PLANNED (Phase 5) |
| Regression that removes controls (happened: `d76a0c6`) | High / High | full test suite + rules in `docs/PARALLEL_WORK.md` | no CI gate yet (PLANNED) |

---

## 2. Threat modelling and design review

- **Method:** STRIDE per flow, recorded in `docs/security/THREAT_MODEL.md`; attack scenarios with expected vs actual results in `docs/security/ATTACK_SCENARIOS.md`; journeys in `docs/USER_JOURNEYS_AND_SECURITY.md`.
- **Flows modelled (IMPLEMENTED):** authentication, claim submission, evidence upload, insurer workflow (verify → screen → review), decision, payout, audit, queue/OCR boundary.
- **Flows to model before they are built (PLANNED):** identity verification / eKYC (provider trust boundary, ID-number handling, replay), real payout rail (destination verification, idempotency across the rail, reconciliation).
- **Design rules every reviewer checks:** new route mounted under `/api/v1` behind `requireActor`; role gate is resource-independent; object load applies the tenant boundary; any stage change goes through `transitionClaim`; a new table holding claim data carries `tenant_id`; new sensitive action writes an audit event; no new "admin" shortcut. The unmounted MVC layer stays unmounted until it satisfies these (`BACKEND-SEC-021`).
- **Review artefacts:** each phase ships a precheck (what actually exists) and a report (what changed, tests, attacks, limitations) under `docs/phase-reports/`.

---

## 3. Secure development practices

| Practice | Status | Evidence |
|---|---|---|
| Strict input validation on every body/param/query; unknown fields rejected | IMPLEMENTED | `src/security/validation.ts` (zod `.strict()`), `test/massAssignment.test.ts` |
| Parameterised queries only; no string-built SQL | IMPLEMENTED | all `DB.prepare(...).bind(...)`; reviewed per phase |
| File validation: allowlist, magic bytes, size cap, sanitised names, server-generated keys | IMPLEMENTED | `src/security/evidence.ts`, `test/evidence.test.ts` |
| Central state machine; single stage-writer with optimistic concurrency and atomic audit | IMPLEMENTED | `src/security/claimStateMachine.ts`, `transitionClaim` |
| Fail closed on misconfiguration (missing secret/issuer/audience → 401) | IMPLEMENTED | `test/auth.test.ts` AUTH-009/010 |
| Generic error bodies, no stack traces; server-generated request ids | IMPLEMENTED | `src/index.ts`, `test/hardening.test.ts` |
| Rate limits per IP and per actor; 64 KB body limit; security headers; CORS allowlist | IMPLEMENTED | `src/index.ts` |
| No secrets in code; `.dev.vars` and Postman environments git-ignored; per-run test secret | IMPLEMENTED | `.gitignore`, `vitest.config.mts` |
| Least privilege by role and per transition (assessors prepare, managers decide/pay, admin has no claim access) | IMPLEMENTED | state machine roles |
| Coding standard / lint in CI | PLANNED | none configured |

Branching rules for parallel work (reserved migration numbers, file ownership, rebase before PR, never commit to `cyber`): `docs/PARALLEL_WORK.md`.

---

## 4. Security testing

| Layer | Status | What runs |
|---|---|---|
| Unit + integration security tests in the Workers runtime (real D1, R2, queue) | IMPLEMENTED | `npm test`: 15 files, 232 tests — authentication, BOLA, tenant isolation, RBAC, mass assignment, state machine, evidence, decision/payout, audit integrity, queue/prompt-injection, hardening |
| Live attack execution against `wrangler dev` with recorded evidence | IMPLEMENTED (per phase) | `docs/phase-reports/evidence/*.log`, `docs/quantum/` |
| Mutation checks (disable a control, confirm tests fail) | done manually in Phases 0/1 | documented in phase reports |
| Type checking | IMPLEMENTED | `npm run typecheck` |
| Dependency scanning | PARTIAL | `npm audit` run per phase (0 vulnerabilities on `main`); Dependabot/Snyk PLANNED |
| SAST (injection, hard-coded secrets, insecure deserialisation) | PLANNED | candidates: `semgrep` with the OWASP/TypeScript rulesets, `gitleaks` for secrets, run in CI |
| DAST / fuzzing of the API | PLANNED | the Postman attack folders (0, 5–8) are a manual DAST baseline; automate with Newman in CI |
| Regression gate | PLANNED | GitHub Actions: typecheck + `npm test` + `npm audit` + secret scan on every PR to `main` (would have blocked the `d76a0c6` regression) |

Rule: a security-sensitive change ships with a test that fails without it. "Never call planned work implemented; never call an unrun test passed" (master plan §18).

---

## 5. Third-party assessment and secure integration

| Integration | Status | Assessment / integration rules |
|---|---|---|
| Cloudflare Workers, D1, R2, Queues, Rate Limiting | IMPLEMENTED | Shared-responsibility: Cloudflare secures the platform; we own authorization, data classification, secrets (`wrangler secret`), private bucket, per-environment config (`[env.production]` PLANNED, `BACKEND-SEC-018`). |
| Identity provider (JWKS) | PLANNED (`BACKEND-SEC-019`) | Switch `resolveActor` to `verifyWithJwks`; asymmetric keys, `kid` rotation; the claim rules (role, tenant, TTL) stay ours. |
| Home Affairs eKYC / identity verification | PLANNED | Provider risk review (data residency, retention, breach terms); send the minimum; store a verification result and reference, never the raw ID document unless classified High and encrypted; audit every verification. |
| Payment / payout rail | PLANNED (`BACKEND-SEC-006`) | Only after a recorded, approved decision; amount and destination from our ledger, never from the request; rail-side idempotency key = our `payouts.id`; destination verification and step-up for changes; reconciliation against `payouts`. |
| OCR / AI providers | PLANNED (`BACKEND-SEC-008`) | Output is an advisory, schema-validated signal; never calls `transitionClaim`; documents are hostile input (prompt injection). |
| Quantum screening (in-house, simulator) | IMPLEMENTED, advisory | Read-only signal after `/screen`; cannot move a claim. |

Integration test rule: every external boundary gets a test that feeds it hostile input (bad signature, oversized/relabelled file, injected text, replayed request) and asserts no state change — the pattern already used for the queue and evidence routes. Tenant data is never pooled across insurers; encryption at rest is Cloudflare-managed, and per-tenant keys are DECISION REQUIRED if a contractual need appears.

---

## 6. Release, deployment and operations

| Control | Status |
|---|---|
| Pre-deploy checklist (`docs/security/SECURITY_CHECKLIST.md`): secrets via `wrangler secret`, distinct issuer/audience per environment, real D1 id, bucket provisioned, migrations applied, tests green | IMPLEMENTED as a checklist; automation PLANNED |
| Environment separation (`[env.production]`) | PLANNED |
| Monitoring: alert on spikes of `outcome = 'denied'` audit rows per actor/tenant, and on `payout.blocked` | PLANNED |
| Audit retention/export and immutability beyond DB triggers | PLANNED (Phase 5 signing) |
| Incident response: rotate `JWT_SECRET` (invalidates all tokens), disable the affected tenant's staff tokens at the IdP, review audit trail by `request_id` | PARTIAL (rotation possible; no runbook yet) |
| Key management for future ML-DSA signatures | DECISION REQUIRED |

---

## 7. Roles and ownership

| Area | Owner |
|---|---|
| Security requirements, threat model, tests, attack evidence, this SSDLC | Cyber track |
| Business rules (separation of duties, appeal limit, admin scope, consent/retention) | Product + security owners (DECISION REQUIRED items in `BACKEND_SECURITY_HANDOFF.md` 015–020) |
| Backend features, integrations, CI, environments | Backend team, following §2 design rules |
| Flutter app: must obtain a token and call only customer routes; no local authorization logic | Frontend (backend team) |
| Quantum/PQC | Quantum track (advisory signal only; Phase 5 signing) |
