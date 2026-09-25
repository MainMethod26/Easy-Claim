# Backend Security Handoff

**Question answered:** What does the backend team need to implement so the cyber team can test and verify the system?

## Already delivered by cyber (branch `cyber`)

| Module | What it gives you |
|---|---|
| `backend/src/types.ts` | `Role`, `Actor`, `Bindings`, `AppEnv` |
| `backend/src/security/actor.ts` | `requireActor` middleware; `resolveActor()` — the single function to replace with real auth |
| `backend/src/security/rbac.ts` | `requireRole(...roles)` |
| `backend/src/security/claimAccess.ts` | `loadAuthorizedClaim(c, id, 'read' \| 'owner-write')`, `transitionClaim(c, claim, to)` |
| `backend/src/security/claimStateMachine.ts` | `TRANSITIONS`, `checkTransition()` |
| `backend/src/security/audit.ts` | `writeAuditEvent(c, event)` |
| `backend/src/security/validation.ts` | strict zod schemas + `validate()` |
| `backend/migrations/0002_security.sql` | claim columns, `audit_events` (append-only), `evidence` table |
| `backend/test/*.test.ts` | 85 tests (run `npm test`) |

## Requirements

### BACKEND-SEC-001 — Real authentication
- **Requirement:** Replace the body of `resolveActor()` in `backend/src/security/actor.ts` with verified identity (e.g. `hono/jwt` HS256 with pinned `alg`, `JWT_SECRET` via `wrangler secret put`, required `sub`, `role`, `exp`; or a managed IdP). Return `null` on any failure.
- **Why:** Today identity comes from spoofable headers (OWASP API2).
- **Status:** NOT IMPLEMENTED.
- **Acceptance:** missing/expired/bad-signature/`alg:none` tokens → 401; `test/actor.test.ts` still passes with dev flag off; add JWT tests (SECURITY_TEST_PLAN AUTHN-06..08).

### BACKEND-SEC-002 — Tenant/org scoping for insurer roles
- **Requirement:** Add `organization_id` to actor, policies, claims. In `loadAuthorizedClaim()`, insurer roles may only access claims of their organization.
- **Why:** Any ASSESSOR/MANAGER can currently read every claim (BOLA across insurers).
- **Status:** NOT IMPLEMENTED.
- **Acceptance:** assessor of org X → claim of org Y → 404 + `authz.claim_access_denied`.

### BACKEND-SEC-003 — Insurer workflow endpoints through the state machine
- **Requirement:** New endpoints for verify, screen, info-needed, review, decide, pay MUST use `requireRole(...)`, `loadAuthorizedClaim(c, id, 'read')` (+ org check) and `transitionClaim()`. Never `UPDATE claims SET stage` directly.
- **Why:** Illegal transitions (Submitted→Paid, customer decides) are blocked only if every path uses the validator.
- **Status:** NOT IMPLEMENTED (only customer routes exist).
- **Acceptance:** API tests mirroring `test/stateMachine.test.ts` cases return 409/403 over HTTP.

### BACKEND-SEC-004 — Strict schemas on every new endpoint
- **Requirement:** Use `validate('json', z.object({...}).strict())` from `validation.ts`; never spread request bodies into DB writes; set `user_id`, `stage`, `status`, decision/payout fields server-side only.
- **Status:** IMPLEMENTED for existing routes.
- **Acceptance:** extend `test/massAssignment.test.ts` for each new route.

### BACKEND-SEC-005 — Decision record
- **Requirement:** Table `decisions` (claim_id, decision, amount, actor_id, actor_role, timestamp, rules_version, model_version, evidence hashes, screening result, reason), written in the same `DB.batch` as the `Review → Decision` transition. `GET /claims/:id/decision` reads it.
- **Status:** NOT IMPLEMENTED (`/decision` returns `claims.status`).
- **Acceptance:** decision without reason → 400; customer → 403; record present for every Decision.

### BACKEND-SEC-006 — Payout protections
- **Requirement:** Payout only from Decision/Approved by MANAGER; idempotency key per claim; verified destination; step-up auth for destination changes; high-value threshold requires second approver; audit `payout.*` events.
- **Status:** NOT IMPLEMENTED (state machine already restricts `Decision → Paid` to MANAGER).
- **Acceptance:** duplicate payout → 409; assessor payout → 403.

### BACKEND-SEC-007 — Evidence upload
- **Requirement:** R2 bucket binding; server-generated `storage_key`; size limit; MIME + magic-byte allowlist (PDF/JPEG/PNG); compute SHA-256 into `evidence.sha256`; row in existing `evidence` table linked to `claim_id` and `uploaded_by`; only owner (or scoped insurer) can read; no overwrite — new version instead; audit `evidence.uploaded`.
- **Status:** NOT IMPLEMENTED (`evidence-ocr` only queues an event).
- **Acceptance:** oversized → 413; `.exe` → 415; other customer download → 404; hash matches.

### BACKEND-SEC-008 — OCR/AI output as untrusted signal
- **Requirement:** OCR/AI returns a zod-validated risk signal only; it must never call `transitionClaim()`. See `AI_SECURITY.md`.
- **Status:** NOT IMPLEMENTED (no OCR). Queue message validation IMPLEMENTED.

### BACKEND-SEC-009 — Configuration change audit
- **Requirement:** Fraud thresholds, payout limits, roles stored as versioned config; changes ADMIN-only with actor, old/new value, reason, version in `audit_events`.
- **Status:** NOT IMPLEMENTED (no config exists).

### BACKEND-SEC-010 — Replace stubs with actor-scoped data
- **Requirement:** `/profile/*`, `/client/*` (hardcoded alerts/activity), `/activities/*`, `/profile/mandates/:tenantId/check` must query data for `c.get('actor').id` only; `PATCH /profile` needs a strict schema.
- **Status:** stubs; now behind `requireActor`.
- **Acceptance:** customer B sees none of customer A's data.

### BACKEND-SEC-011 — Queue consumer in local dev
- **Requirement:** Investigate why `processQueueBatch` does not fire under `wrangler dev` (it did not before the cyber changes either); logic is covered by `test/queue.test.ts`.
- **Status:** OPEN.

### BACKEND-SEC-012 — Rate limits per user
- **Requirement:** After auth, key the limiter on actor id as well as IP; stricter limits on login and expensive routes (upload/OCR).
- **Status:** PARTIAL (per-IP, 100/60 s).

### BACKEND-SEC-013 — Atomic audit writes
- **Requirement:** In `transitionClaim()`, combine the conditional UPDATE and the audit INSERT via `c.env.DB.batch()` so a state change never exists without its audit row.
- **Status:** PARTIAL (sequential writes).

### BACKEND-SEC-014 — Keep the tests green
- **Requirement:** `npm test`, `npm run typecheck`, `npm audit` pass on every PR; new sensitive routes ship with BOLA, RBAC and mass-assignment tests.
- **Status:** IMPLEMENTED locally; CI NOT IMPLEMENTED.
