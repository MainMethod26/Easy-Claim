import { env } from 'cloudflare:workers'
import { ml_dsa65 } from '@noble/post-quantum/ml-dsa.js'
import { describe, expect, it } from 'vitest'
import { canonicalBundle, signDecision, getSigner } from '../src/security/integrity'
import { sha256Hex } from '../src/security/ledger'
import {
  assessorA,
  assessorB,
  auditRows,
  call,
  claimStage,
  createReviewedClaim,
  customerA,
  customerB,
  decisionRows,
  managerA,
  payoutRows,
} from './helpers'

// Phase 5: post-quantum decision integrity (ML-DSA-65, FIPS 204).
const APPROVE = { outcome: 'Approved', reason: 'Documents verified, within cover' } as const
const b64 = (s: string) => Uint8Array.from(atob(s), (ch) => ch.charCodeAt(0))

async function decided(): Promise<{ id: string; decisionId: string }> {
  const id = await createReviewedClaim()
  const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: APPROVE })
  if (res.status !== 200) throw new Error(`decide failed: ${res.status} ${await res.text()}`)
  return { id, decisionId: ((await res.json()) as { decisionId: string }).decisionId }
}

async function verify(id: string, as: { id: string; role: string; tenantId?: string } = managerA) {
  const res = await call(`/claims/${id}/decision/verify`, { as })
  return { status: res.status, body: (await res.json()) as { integrity: { status: string; keyId: string | null } } }
}

/** Simulates an insider with raw database access: the append-only trigger is dropped first. */
async function tamper(sql: string, ...binds: unknown[]) {
  await env.DB.exec('DROP TRIGGER IF EXISTS claim_decisions_no_update')
  await env.DB.prepare(sql).bind(...binds).run()
}

describe('PQC-01..03: every decision is ML-DSA-65 signed and independently verifiable', () => {
  it('decide stores alg, key id, bundle digest and a 3309-byte ML-DSA-65 signature', async () => {
    const { id } = await decided()
    const row = (await decisionRows(id))[0]
    const key = (await (await call('/integrity/public-key', { as: customerA })).json()) as { alg: string; keyId: string; publicKey: string; standard: string }
    expect(key).toMatchObject({ alg: 'ML-DSA-65', standard: 'NIST FIPS 204' })
    expect(b64(key.publicKey)).toHaveLength(1952)
    expect(row).toMatchObject({ integrity_alg: 'ML-DSA-65', integrity_key_id: key.keyId })
    expect(b64(row.integrity_signature as string)).toHaveLength(3309)
    expect(row.integrity_bundle_digest).toBe(await sha256Hex(canonicalBundle(row as never)))
    expect((await auditRows('claim.decision_recorded'))[0].details as string).toContain('ML-DSA-65')
  })

  it('verify: VALID for the owner and the tenant staff; audited', async () => {
    const { id, decisionId } = await decided()
    for (const who of [customerA, assessorA, managerA]) {
      const r = await verify(id, who)
      expect(r.status).toBe(200)
      expect(r.body.integrity.status).toBe('VALID')
    }
    const rows = await auditRows('decision.integrity_verified', decisionId)
    expect(rows).toHaveLength(3)
    expect(JSON.parse(rows[0].details as string)).toMatchObject({ status: 'VALID' })
  })

  it('an outside verifier with only the public key and the stored row gets the same answer', async () => {
    const { id } = await decided()
    const row = (await decisionRows(id))[0]
    const key = (await (await call('/integrity/public-key', { as: managerA })).json()) as { publicKey: string; context: string }
    const ok = ml_dsa65.verify(
      b64(row.integrity_signature as string),
      new TextEncoder().encode(canonicalBundle(row as never)),
      b64(key.publicKey),
      { context: new TextEncoder().encode(key.context) }
    )
    expect(ok).toBe(true)
  })

  it('verify inherits access control: other customer 404, other tenant 404, no token 401', async () => {
    const { id } = await decided()
    expect((await verify(id, customerB)).status).toBe(404)
    expect((await verify(id, assessorB)).status).toBe(404)
    expect((await call(`/claims/${id}/decision/verify`)).status).toBe(401)
    expect((await call('/integrity/public-key')).status).toBe(401)
  })
})

describe('PQC-04..07: tampering is detected and payout refuses it', () => {
  it.each([
    ['approved amount raised', 'UPDATE claim_decisions SET approved_amount_cents = 42000000 WHERE claim_id = ?'],
    ['outcome flipped', "UPDATE claim_decisions SET outcome = 'Rejected' WHERE claim_id = ?"],
    ['payout destination swapped', "UPDATE claim_decisions SET destination_hash = 'deadbeef' WHERE claim_id = ?"],
    ['reason rewritten', "UPDATE claim_decisions SET reason = 'approved by the CEO' WHERE claim_id = ?"],
    ['decision-maker changed', "UPDATE claim_decisions SET actor_id = 'someone_else' WHERE claim_id = ?"],
    ['screening signal replaced', "UPDATE claim_decisions SET risk_signal = '{\"band\":\"NORMAL\"}' WHERE claim_id = ?"],
    ['evidence digest replaced', "UPDATE claim_decisions SET evidence_digest = 'feedface' WHERE claim_id = ?"],
  ])('%s → TAMPERED; /pay blocked and audited', async (_name, sql) => {
    const { id } = await decided()
    await tamper(sql, id)
    expect((await verify(id)).body.integrity.status).toBe('TAMPERED')
    const pay = await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })
    expect(pay.status).toBe(409)
    expect(await pay.json()).toEqual({ error: 'decision_integrity_failed' })
    expect(await payoutRows(id)).toHaveLength(0)
    expect(await claimStage(id)).toMatchObject({ stage: 'Decision' })
    const blocked = (await auditRows('payout.blocked', id)).map((r) => JSON.parse(r.details as string))
    expect(blocked).toContainEqual(expect.objectContaining({ reason: 'decision_integrity_failed', integrity: 'TAMPERED' }))
  })

  it('stripped signature → UNSIGNED; payout blocked', async () => {
    const { id } = await decided()
    await tamper('UPDATE claim_decisions SET integrity_signature = NULL WHERE claim_id = ?', id)
    expect((await verify(id)).body.integrity.status).toBe('UNSIGNED')
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(409)
  })

  it('attacker re-signs a forged bundle with their own key → UNKNOWN_KEY (or TAMPERED if they keep our key id)', async () => {
    const { id } = await decided()
    const row = (await decisionRows(id))[0]
    const attacker = (await getSigner('ab'.repeat(32)))!
    const forged = { ...(row as never as Parameters<typeof canonicalBundle>[0]), approved_amount_cents: 42000000 }
    const sig = await signDecision(attacker, forged)
    await tamper(
      'UPDATE claim_decisions SET approved_amount_cents = ?, integrity_signature = ?, integrity_key_id = ?, integrity_bundle_digest = ? WHERE claim_id = ?',
      42000000, sig.integrity_signature, sig.integrity_key_id, sig.integrity_bundle_digest, id
    )
    expect((await verify(id)).body.integrity.status).toBe('UNKNOWN_KEY')
    await env.DB.prepare('UPDATE claim_decisions SET integrity_key_id = ? WHERE claim_id = ?').bind(row.integrity_key_id, id).run()
    expect((await verify(id)).body.integrity.status).toBe('TAMPERED')
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(409)
  })

  it('a valid signature copied from another decision does not verify here; garbage signatures fail safely', async () => {
    const a = await decided()
    const b = await decided()
    const sigA = (await decisionRows(a.id))[0].integrity_signature as string
    await tamper('UPDATE claim_decisions SET integrity_signature = ? WHERE claim_id = ?', sigA, b.id)
    expect((await verify(b.id)).body.integrity.status).toBe('TAMPERED')
    await env.DB.prepare("UPDATE claim_decisions SET integrity_signature = 'not-base64!!' WHERE claim_id = ?").bind(b.id).run()
    expect((await verify(b.id)).body.integrity.status).toBe('TAMPERED')
    await env.DB.prepare("UPDATE claim_decisions SET integrity_signature = 'AAAA' WHERE claim_id = ?").bind(b.id).run()
    expect((await verify(b.id)).body.integrity.status).toBe('TAMPERED')
    // the untouched decision still verifies and pays
    expect((await verify(a.id)).body.integrity.status).toBe('VALID')
    expect((await call(`/claims/${a.id}/pay`, { method: 'POST', as: managerA })).status).toBe(200)
  })
})

describe('PQC-08..10: fail closed, and the signature never authorises anything', () => {
  it('without MLDSA_SEED no decision is recorded (503, audited); verify reports UNAVAILABLE; public key 503', async () => {
    const id = await createReviewedClaim()
    const noKey = { MLDSA_SEED: undefined }
    const res = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: APPROVE, env: noKey })
    expect(res.status).toBe(503)
    expect(await res.json()).toEqual({ error: 'integrity_unavailable' })
    expect(await decisionRows(id)).toHaveLength(0)
    expect(await claimStage(id)).toMatchObject({ stage: 'Review' })
    expect(JSON.parse((await auditRows('claim.decision_rejected', id))[0].details as string)).toMatchObject({ reason: 'integrity_unavailable' })
    expect((await call('/integrity/public-key', { as: managerA, env: noKey })).status).toBe(503)

    const { id: signedId } = await decided()
    expect((await call(`/claims/${signedId}/decision/verify`, { as: managerA, env: noKey })).status).toBe(200)
    expect(((await (await call(`/claims/${signedId}/decision/verify`, { as: managerA, env: noKey })).json()) as { integrity: { status: string } }).integrity.status).toBe('UNAVAILABLE')
    expect((await call(`/claims/${signedId}/pay`, { method: 'POST', as: managerA, env: noKey })).status).toBe(409)
  })

  it('a different deployment key does not verify existing decisions (UNKNOWN_KEY)', async () => {
    const { id } = await decided()
    const r = await call(`/claims/${id}/decision/verify`, { as: managerA, env: { MLDSA_SEED: 'cd'.repeat(32) } })
    expect(((await r.json()) as { integrity: { status: string } }).integrity.status).toBe('UNKNOWN_KEY')
  })

  it('signing does not grant authority: customers and assessors still cannot decide; verify has no write counterpart', async () => {
    const id = await createReviewedClaim()
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: customerA, json: APPROVE })).status).toBe(403)
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: assessorA, json: APPROVE })).status).toBe(403)
    for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
      expect([404, 405]).toContain((await call(`/claims/${id}/decision/verify`, { method, as: managerA, json: {} })).status)
    }
    expect(await decisionRows(id)).toHaveLength(0)
  })

  it('no decision yet → NO_DECISION', async () => {
    const id = await createReviewedClaim()
    const r = (await (await call(`/claims/${id}/decision/verify`, { as: managerA })).json()) as { integrity: { status: string } }
    expect(r.integrity.status).toBe('NO_DECISION')
  })
})
