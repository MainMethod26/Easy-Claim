import { describe, expect, it } from 'vitest'
import { env } from 'cloudflare:workers'
import {
  assessorA,
  assessorB,
  auditRows,
  call,
  createReadyDraft,
  customerA,
  customerB,
  evidenceFile,
  evidenceRow,
  VALID_PDF_BYTES,
  VALID_PNG_BYTES,
} from './helpers'

function pdfForm(file: File = evidenceFile()): FormData {
  const form = new FormData()
  form.set('file', file)
  return form
}

describe('evidence upload authorization', () => {
  it('unauthenticated upload is rejected (401)', async () => {
    const res = await call('/claims/claim_disc_101/evidence', { method: 'POST', formData: pdfForm() })
    expect(res.status).toBe(401)
  })

  it("customer B cannot upload against customer A's draft claim (404, no existence oracle)", async () => {
    const claimId = await createReadyDraft()
    const res = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerB, formData: pdfForm() })
    expect(res.status).toBe(404)
    const body = await res.text()
    expect(body).not.toContain(claimId)
    expect(body).not.toContain('user123')
  })

  it('a non-CUSTOMER role is rejected (403)', async () => {
    const claimId = await createReadyDraft()
    const res = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: assessorA, formData: pdfForm() })
    expect(res.status).toBe(403)
  })

  it('evidence cannot be attached once the claim has left the editable stage (409)', async () => {
    // claim_disc_101 is owned by customerA but already at stage Review.
    const res = await call('/claims/claim_disc_101/evidence', { method: 'POST', as: customerA, formData: pdfForm() })
    expect(res.status).toBe(409)
  })

  it('a valid authorized upload succeeds and is audited', async () => {
    const claimId = await createReadyDraft()
    const res = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm() })
    expect(res.status).toBe(201)
    const { evidenceId, sha256 } = (await res.json()) as { evidenceId: string; sha256: string }
    expect(evidenceId).toMatch(/^ev_/)
    expect(sha256).toHaveLength(64)

    const row = await evidenceRow(evidenceId)
    expect(row).toMatchObject({ claim_id: claimId, uploaded_by: 'user123', tenant_id: 'ins_discovery', mime_type: 'application/pdf' })

    const rows = await auditRows('evidence.uploaded', evidenceId)
    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({ actor_id: 'user123', outcome: 'success' })
  })

  it('a client-supplied owner/tenant id in the form is ignored, not honoured', async () => {
    const claimId = await createReadyDraft()
    const form = pdfForm()
    form.set('uploadedBy', 'someone_else')
    form.set('tenantId', 'ins_sanlam')
    form.set('claimId', 'claim_sanlam_102')
    const res = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: form })
    expect(res.status).toBe(201)
    const { evidenceId } = (await res.json()) as { evidenceId: string }
    const row = await evidenceRow(evidenceId)
    expect(row).toMatchObject({ claim_id: claimId, uploaded_by: 'user123', tenant_id: 'ins_discovery' })
  })

  it('rejects a declared type outside the allowlist', async () => {
    const claimId = await createReadyDraft()
    const file = new File([VALID_PDF_BYTES], 'archive.zip', { type: 'application/zip' })
    const res = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm(file) })
    expect(res.status).toBe(415)
    const rows = await auditRows('evidence.rejected', claimId)
    expect(rows.some((r) => (JSON.parse(r.details as string) as { reason: string }).reason === 'unsupported_type')).toBe(true)
  })

  it('rejects a file whose content does not match its declared (allowlisted) type', async () => {
    const claimId = await createReadyDraft()
    // PNG bytes declared as a PDF: passes the allowlist, fails the magic-byte check.
    const file = new File([VALID_PNG_BYTES], 'fake.pdf', { type: 'application/pdf' })
    const res = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm(file) })
    expect(res.status).toBe(415)
    const rows = await auditRows('evidence.rejected', claimId)
    expect(rows.some((r) => (JSON.parse(r.details as string) as { reason: string }).reason === 'magic_bytes_mismatch')).toBe(true)
  })

  it('rejects a file over the size limit', async () => {
    const claimId = await createReadyDraft()
    const oversized = new Uint8Array(10 * 1024 * 1024 + 1024)
    oversized.set(VALID_PDF_BYTES.subarray(0, 5))
    const file = new File([oversized], 'huge.pdf', { type: 'application/pdf' })
    const res = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm(file) })
    expect(res.status).toBe(413)
    const rows = await auditRows('evidence.rejected', claimId)
    expect(rows.some((r) => (JSON.parse(r.details as string) as { reason: string }).reason === 'size')).toBe(true)
  })

  it('there is no route to modify stored evidence metadata after upload', async () => {
    const claimId = await createReadyDraft()
    const uploaded = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm() })
    const { evidenceId } = (await uploaded.json()) as { evidenceId: string }
    const res = await call(`/claims/${claimId}/evidence/${evidenceId}`, {
      method: 'PATCH',
      as: customerA,
      json: { displayName: 'renamed.pdf', sha256: 'a'.repeat(64) },
    })
    expect(res.status).toBe(404)
    const row = await evidenceRow(evidenceId)
    expect(row?.display_name).toBe('receipt.pdf') // unchanged: the PATCH route does not exist
  })
})

describe('evidence read authorization (IDOR / cross-tenant)', () => {
  it("customer B cannot download or list customer A's evidence (404, no metadata leak)", async () => {
    const claimId = await createReadyDraft()
    const uploaded = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm() })
    const { evidenceId, sha256 } = (await uploaded.json()) as { evidenceId: string; sha256: string }

    const list = await call(`/claims/${claimId}/evidence`, { as: customerB })
    expect(list.status).toBe(404)

    const download = await call(`/claims/${claimId}/evidence/${evidenceId}`, { as: customerB })
    expect(download.status).toBe(404)
    const body = await download.text()
    expect(body).not.toContain(sha256)
    expect(body).not.toContain('receipt.pdf')
  })

  it('insurer staff of a different tenant cannot list, download or verify evidence (404)', async () => {
    const claimId = await createReadyDraft()
    const uploaded = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm() })
    const { evidenceId } = (await uploaded.json()) as { evidenceId: string }
    const submitted = await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
    expect(submitted.status).toBe(200)

    // Tenant A (the claim's own insurer) can see it.
    expect((await call(`/claims/${claimId}/evidence`, { as: assessorA })).status).toBe(200)
    expect((await call(`/claims/${claimId}/evidence/${evidenceId}`, { as: assessorA })).status).toBe(200)

    // Tenant B (a different insurer) cannot.
    expect((await call(`/claims/${claimId}/evidence`, { as: assessorB })).status).toBe(404)
    expect((await call(`/claims/${claimId}/evidence/${evidenceId}`, { as: assessorB })).status).toBe(404)
    expect((await call(`/claims/${claimId}/evidence/${evidenceId}/verify`, { as: assessorB })).status).toBe(404)
  })

  it('a successful download is audited', async () => {
    const claimId = await createReadyDraft()
    const uploaded = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm() })
    const { evidenceId } = (await uploaded.json()) as { evidenceId: string }
    await call(`/claims/${claimId}/evidence/${evidenceId}`, { as: customerA })
    const rows = await auditRows('evidence.accessed', evidenceId)
    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({ outcome: 'success' })
  })
})

describe('evidence integrity verification', () => {
  it('unmodified evidence verifies as VALID', async () => {
    const claimId = await createReadyDraft()
    const uploaded = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm() })
    const { evidenceId } = (await uploaded.json()) as { evidenceId: string }

    const res = await call(`/claims/${claimId}/evidence/${evidenceId}/verify`, { as: customerA })
    expect(res.status).toBe(200)
    const body = (await res.json()) as { status: string }
    expect(body.status).toBe('VALID')

    const rows = await auditRows('evidence.integrity_verified', evidenceId)
    expect(rows[0]).toMatchObject({ outcome: 'success' })
  })

  it('content modified at rest is detected: HASH-A != HASH-B and status TAMPERED', async () => {
    const claimId = await createReadyDraft()
    const uploaded = await call(`/claims/${claimId}/evidence`, { method: 'POST', as: customerA, formData: pdfForm() })
    const { evidenceId, sha256: hashA } = (await uploaded.json()) as { evidenceId: string; sha256: string }

    const row = await evidenceRow(evidenceId)
    expect(row).not.toBeNull()
    // Simulate tampering with the stored object directly (bypassing the API entirely).
    const tampered = new Uint8Array(VALID_PDF_BYTES)
    tampered[tampered.length - 1] ^= 0xff
    await env.EVIDENCE_BUCKET!.put(row!.storage_key, tampered)

    const res = await call(`/claims/${claimId}/evidence/${evidenceId}/verify`, { as: customerA })
    expect(res.status).toBe(200)
    const body = (await res.json()) as { status: string; expectedHash: string; actualHash: string }
    expect(body.status).toBe('TAMPERED')
    expect(body.expectedHash).toBe(hashA)
    expect(body.actualHash).not.toBe(hashA) // HASH-A != HASH-B

    const rows = await auditRows('evidence.integrity_verified', evidenceId)
    const failure = rows.find((r) => r.outcome === 'failure')
    expect(failure).toBeDefined()
  })
})
