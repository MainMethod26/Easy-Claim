# Evidence Security

## Actual state

`POST /api/v1/claims/:claimId/evidence-ocr` (`backend/src/endpoints/claims.ts`) **accepts no file**. It:

1. requires `CUSTOMER` and ownership of the claim (`loadAuthorizedClaim(..., 'owner-write')`); anyone else gets 404;
2. requires the claim stage to be `Draft` or `Info Needed` (otherwise 409);
3. sends `{event:'ClaimEvidenceUploaded', data:{claimId, timestamp}}` to the `CLAIM_EVENTS` queue;
4. writes the audit event `claim.evidence_queued`.

The queue consumer (`backend/src/endpoints/ocr.ts`) now validates the message and logs it. Previously this event was silently dropped. There is no storage binding (no R2) and no OCR engine.

The `evidence` table (`backend/migrations/0002_security.sql`: `id, claim_id, uploaded_by, storage_key, mime_type, size_bytes, sha256, created_at`) exists but **no code uses it**.

## Assessment (Phase 8 checklist)

| Control | Status | Notes |
|---|---|---|
| Authentication | PARTIAL | Actor required. Real auth NOT IMPLEMENTED (dev stub) |
| Authorization (owner only) | IMPLEMENTED, TESTED/PASSED | `test/bola.test.ts` |
| File size limits | NOT IMPLEMENTED | No file accepted. Global JSON body limit is 64 KB (`src/index.ts`) |
| File type allowlist | NOT IMPLEMENTED | — |
| MIME validation | NOT IMPLEMENTED | — |
| Extension validation | NOT IMPLEMENTED | — |
| Filename handling | N/A today | No filenames accepted |
| Storage location | NOT IMPLEMENTED | No storage binding |
| Generated storage names | NOT IMPLEMENTED | `storage_key` column ready |
| Path traversal | N/A today | `claimId` is regex-validated (`^[A-Za-z0-9_-]{1,64}$`); the queue rejects `../` IDs (`test/queue.test.ts`) |
| Executable / malicious files | NOT IMPLEMENTED | — |
| Archive bombs | N/A | Archives must not be accepted |
| OCR processing isolation | NOT IMPLEMENTED | No OCR. It must run in the async consumer, never inline |
| OCR failure handling | PARTIAL | Consumer retries on exceptions and acks malformed messages (no poison loop) |
| Evidence ownership | PARTIAL | Claim ownership enforced. The per-evidence `claim_id` + `uploaded_by` columns exist but are unused |
| Evidence replacement | NOT IMPLEMENTED | Should be supersede-only after submit |
| Evidence deletion | NOT IMPLEMENTED | Only allowed before submit, and audited |
| Evidence integrity (SHA-256) | NOT IMPLEMENTED | `sha256` column ready |
| Sensitive data exposure | PARTIAL | Audit rows store no document content (`test/audit.test.ts`) |

## Design for real upload (backend team, P1)

1. **Transport.** Workers request bodies are platform-limited (100 MB+ depending on plan), so apply an app limit of **10 MB** per file.
   - Either accept `multipart/form-data` on a route that gets its own `bodyLimit`,
   - or issue a presigned R2 upload URL scoped to one server-generated key.
2. **Storage.** A private R2 bucket with no public access.
   - Key: `claims/{claimId}/{crypto.randomUUID()}`. Never use the client filename in the key; keep it (sanitised) only as metadata.
3. **Allowlist.** Accept only `application/pdf`, `image/jpeg` and `image/png`. Verify **magic bytes**:
   - PDF: `%PDF-`
   - JPEG: `FF D8 FF`
   - PNG: `89 50 4E 47`
   - Reject when the declared MIME and the magic bytes disagree. Reject archives, Office files and SVG.
4. **Integrity.** Compute SHA-256 (`crypto.subtle.digest`) on upload and store it in `evidence.sha256`. Decision records reference these hashes (DECISION_SECURITY.md).
5. **Ownership.** Insert `claim_id` and `uploaded_by = actor.id`. Every evidence read or delete goes through `loadAuthorizedClaim` on the parent claim plus an `evidence.claim_id` match.
6. **Lifecycle.** Delete only in `Draft`/`Info Needed`. After submit, evidence is immutable and new files supersede old ones.
7. **Audit events:** `evidence.uploaded` (id, sha256, size, mime), `evidence.deleted`, `evidence.rejected` (reason). Never include file content.
8. **Processing.** Enqueue the evidence ID only. The consumer loads it from R2, and OCR output is an untrusted signal (AI_SECURITY.md).
9. **Out of scope for the hackathon:** antivirus and content disarm and reconstruction (CDR). Note as P2.
