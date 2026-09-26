# Phase 2 Precheck: Evidence Security + Integrity

Date: 2026-09-25 · Branch: `main` · HEAD at precheck: `f801e9b`
Method: static read of the current backend (routes, security modules, schema, migrations, tests) against `docs/phase-plans/PHASE_02_PROMPT.md` and the existing `docs/security/EVIDENCE_SECURITY.md` plan. Nothing was modified for this document.

## 1. Phase 0 controls present

Confirmed by reading the code (not re-asserted from prior reports): request-id middleware, `secureHeaders()`, CORS allowlist (no wildcard), global JSON body limit (`src/index.ts`), approximate per-IP and per-actor rate limiting (`RATE_LIMITER` binding, optional), append-only `audit_events` table with `UPDATE`/`DELETE` triggers (`migrations/0002_security.sql`), strict zod validation on every data-bearing route (`src/security/validation.ts`), centralized claim state machine (`src/security/claimStateMachine.ts`).

## 2. Phase 1 controls actually complete

Confirmed in code: HS256 bearer JWT verification with pinned algorithm, required `iss`/`aud`/`exp`/`iat`, per-role TTL cap, fail-closed on missing/short secret (`src/security/actor.ts`). `Actor { id, role, tenantId }` with tenant required for `ASSESSOR`/`MANAGER`, forbidden for `CUSTOMER` (`src/types.ts`). Object-level authorization via `loadAuthorizedClaim` (`read` / `owner-write` / `insurer` modes), tenant boundary via `isTenantInsurer`, and non-existence-shaped denial (404) for missing, cross-tenant, draft and NULL-tenant claims (`src/security/claimAccess.ts`). Centralized, transactional stage transitions (`transitionClaim`) that re-check ownership/tenant and write state + audit atomically. `requireRole` for coarse role checks (`src/security/rbac.ts`). This matches `docs/PHASE_01_HANDOFF.md`.

## 3. Current evidence functionality, storage model, endpoints, events, tests

- `POST /api/v1/claims/:claimId/evidence-ocr` (`src/endpoints/claims.ts`) accepts **no file body**. It requires `CUSTOMER` + `owner-write` access to the claim, requires stage `Draft`/`Info Needed`, sends a `ClaimEvidenceUploaded` event to the `CLAIM_EVENTS` queue, and writes audit action `claim.evidence_queued`. This endpoint is left in place; it is the wizard's "queue for OCR" step and is unrelated to the new upload/storage surface added in this phase.
- The queue consumer (`src/endpoints/ocr.ts`, `processQueueBatch`) validates message shape with zod and only `console.log`s; it never calls `transitionClaim` or writes to `claims`, so OCR/AI signals cannot affect claim state today (confirmed by reading the function body).
- `POST /api/v1/ocr/process` is a stub (`{ extracted: true }`) restricted to `ASSESSOR`/`MANAGER`, unrelated to customer evidence upload.
- The `evidence` table exists (`migrations/0002_security.sql`: `id, claim_id, uploaded_by, storage_key, mime_type, size_bytes, sha256, created_at`) but **no route reads or writes it**.
- There is no object-storage binding anywhere in `wrangler.toml` (no R2, no KV used for binary content).
- No tests exercise evidence upload, storage, or integrity; `test/bola.test.ts` only checks that `evidence-ocr` (the no-file queue trigger) is blocked for a non-owner.
- `docs/security/EVIDENCE_SECURITY.md` already contains a design (private R2 bucket, magic-byte allowlist, SHA-256, ownership via `loadAuthorizedClaim`) written before this phase; this implementation follows it and updates its status table at the end of the phase.

## 4. Gaps required for this phase

1. No storage binding to hold file bytes privately (no public URLs).
2. No route accepts a file, validates size/type/magic-bytes, sanitizes the filename, or computes a hash.
3. `evidence.tenant_id` and a sanitized display name are not columns on the table yet (needed for tenant-scoped listing and safe `Content-Disposition`).
4. No authorized read/download path for evidence bytes.
5. No integrity verification endpoint (`VALID`/`TAMPERED`).
6. No audit actions for `evidence.uploaded` / `evidence.accessed` / `evidence.rejected` / `evidence.integrity_verified`.
7. No tests for any of the above, including the required IDOR/BOLA and tampering scenarios.

## 5. Anything preventing safe implementation

None found. Cloudflare R2 (`[[r2_buckets]]`) is emulated locally by the existing `@cloudflare/vitest-plugin`/miniflare test harness the same way D1 and Queues already are, so the private-storage design in `docs/security/EVIDENCE_SECURITY.md` can be implemented and tested without new infrastructure. `Actor`, `loadAuthorizedClaim`, `writeAuditEvent`, and the claim state machine are stable and reusable as-is; this phase adds an evidence router and security helpers alongside them without changing their behavior.

Phase 1 is confirmed complete for the parts this phase depends on (authentication, tenant isolation, claim ownership, audit). Building on the real, verified state above.
