# Evidence Security

## Actual state (Phase 2)

Real evidence upload, private storage and integrity verification are implemented in `src/endpoints/evidence.ts` and
`src/security/evidence.ts`. See `docs/phase-reports/PHASE_02_REPORT.md` for the full flow, threat coverage and test
results, and `docs/BACKEND_INVENTORY.md` section 4b for the endpoint table (routes 32-35).

`POST /api/v1/claims/:claimId/evidence-ocr` (`src/endpoints/claims.ts`, wizard step 4) is unchanged from Phase 1: it
still accepts no file and only queues an OCR event. It is a separate step from the upload/storage endpoints below.

The `evidence` table (`migrations/0002_security.sql`, extended by `migrations/0004_evidence_security.sql` with
`tenant_id` and `display_name`) is now written by `POST /claims/:claimId/evidence` and read by the list/download/
verify routes.

## Assessment

| Control | Status | Notes |
|---|---|---|
| Authentication | IMPLEMENTED, TESTED/PASSED | Verified bearer JWT (Phase 1); see `src/security/actor.ts` |
| Authorization (owner + tenant) | IMPLEMENTED, TESTED/PASSED | `loadAuthorizedClaim`; `test/evidence.test.ts` |
| File size limits | IMPLEMENTED, TESTED/PASSED | 10 MB app-level cap plus a content-type-dispatched body limit (`src/index.ts`) so JSON routes stay capped at 64 KB |
| File type allowlist | IMPLEMENTED, TESTED/PASSED | `application/pdf`, `image/jpeg`, `image/png` only |
| MIME validation | IMPLEMENTED, TESTED/PASSED | Declared MIME must also match the file's magic bytes (`matchesMagicBytes`) |
| Extension validation | N/A by design | The extension is never trusted; only content bytes and declared MIME are checked |
| Filename handling | IMPLEMENTED, TESTED/PASSED | Sanitized to `[A-Za-z0-9._-]`, capped at 128 chars, never used in the storage key |
| Storage location | IMPLEMENTED | Private R2 bucket (`EVIDENCE_BUCKET`), no public URL, no r2.dev subdomain |
| Generated storage names | IMPLEMENTED | `claims/{claimId}/{crypto.randomUUID()}`, never the client filename |
| Path traversal | N/A | `claimId`/`evidenceId` are regex-validated; storage keys are fully server-generated |
| Executable / malicious files | PARTIAL | Blocked by allowlist + magic bytes; no antivirus/CDR scanning (deferred, see PHASE_02_REPORT.md section 9) |
| Archive bombs | N/A | Archives are rejected by the allowlist |
| OCR processing isolation | NOT IMPLEMENTED | No OCR engine exists; the consumer only logs (`processQueueBatch`) and never touches claim state |
| OCR failure handling | PARTIAL | Consumer retries on exceptions and acks malformed messages (no poison loop) |
| Evidence ownership | IMPLEMENTED, TESTED/PASSED | `claim_id`, `tenant_id`, `uploaded_by` are all server-derived and stored; evidence rows are looked up by `id AND claim_id` |
| Evidence replacement | NOT IMPLEMENTED (deferred) | Evidence is immutable once uploaded; no supersede/replace endpoint this phase |
| Evidence deletion | NOT IMPLEMENTED (deferred) | No delete endpoint this phase; immutability also satisfies "no metadata modification" (tested) |
| Evidence integrity (SHA-256) | IMPLEMENTED, TESTED/PASSED | Backend-computed hash + `GET .../verify` returning `VALID`/`TAMPERED`; tampering scenario tested |
| Sensitive data exposure | IMPLEMENTED, TESTED/PASSED | Audit rows store hashes/sizes/ids only, never file content; `uploaded_by`/`storage_key` are never returned to insurer staff |

## Design notes carried into the Phase 2 implementation

1. **Transport.** `multipart/form-data`, field `file`, own body-limit tier (10 MB + form overhead) dispatched by
   content-type in `src/index.ts` so JSON routes keep their 64 KB cap.
2. **Storage.** Private R2 bucket, key `claims/{claimId}/{crypto.randomUUID()}`. The client filename is never used
   in the key; it is kept, sanitized, only as `evidence.display_name`.
3. **Allowlist.** `application/pdf`, `image/jpeg`, `image/png`. Magic bytes checked:
   - PDF: `%PDF-`
   - JPEG: `FF D8 FF`
   - PNG: `89 50 4E 47 0D 0A 1A 0A`
   - Declared MIME and magic bytes disagreeing -> `415`. Archives, Office files and SVG are never in the allowlist.
4. **Integrity.** SHA-256 (`crypto.subtle.digest`) computed on upload, stored in `evidence.sha256`;
   `GET .../evidence/:evidenceId/verify` recomputes it and reports `VALID`/`TAMPERED`.
5. **Ownership.** `claim_id`, `tenant_id`, `uploaded_by` inserted from the authorized claim and verified actor, never
   from the request body. Every read/verify goes through `loadAuthorizedClaim` plus an `id AND claim_id` match.
6. **Lifecycle.** No delete/replace endpoint this phase; evidence is immutable once uploaded (deferred, see
   PHASE_02_REPORT.md section 9).
7. **Audit events:** `evidence.uploaded`, `evidence.accessed`, `evidence.rejected` (reason), `evidence.integrity_verified`
   (`success`/`failure`). Never file content.
8. **Processing.** `ClaimEvidenceUploaded` is still enqueued after a successful upload; the consumer
   (`src/endpoints/ocr.ts`) only logs today and cannot affect claim state (see AI_SECURITY.md).
9. **Out of scope for this phase:** antivirus and content-disarm-and-reconstruction (CDR); evidence delete/replace.
