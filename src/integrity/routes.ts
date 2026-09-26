import { Hono } from 'hono'
import type { AppEnv } from '../types'
import { writeAuditEvent } from '../security/audit'
import { loadAuthorizedClaim } from '../security/claimAccess'
import { INTEGRITY_ALG, BUNDLE_VERSION, getSigner, toBase64, verifyDecision } from '../security/integrity'
import { latestDecision } from '../security/ledger'
import { claimIdParam, validate } from '../security/validation'

/**
 * Phase 5: post-quantum decision integrity routes.
 *
 * GET /claims/:claimId/decision/verify  — owner or the claim's tenant staff (same 'read' access as
 *   GET /decision). Re-serialises the stored decision and verifies its ML-DSA-65 signature.
 *   Answers VALID / TAMPERED / UNSIGNED / UNKNOWN_KEY / UNAVAILABLE. Audited.
 * GET /integrity/public-key            — any authenticated actor. The public key and key id, so a
 *   verifier outside the Worker can check a decision bundle independently.
 */
export const decisionIntegrity = new Hono<AppEnv>()

decisionIntegrity.get('/:claimId/decision/verify', validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'read')
  if (!claim) return c.json({ error: 'not_found' }, 404)
  const decision = await latestDecision(c.env.DB, claim.id)
  if (!decision) return c.json({ claimId: claim.id, decisionId: null, integrity: { status: 'NO_DECISION' } })

  const result = await verifyDecision(c.env.MLDSA_SEED, decision)
  await writeAuditEvent(c, {
    action: 'decision.integrity_verified',
    resourceType: 'claim_decision',
    resourceId: decision.id,
    outcome: result.status === 'VALID' ? 'success' : 'failure',
    details: { claimId: claim.id, status: result.status, keyId: result.keyId, bundleDigest: result.bundleDigest, recomputedDigest: result.recomputedDigest },
  })
  return c.json({ claimId: claim.id, decisionId: decision.id, integrity: result })
})

export const integrityInfo = new Hono<AppEnv>()

integrityInfo.get('/public-key', async (c) => {
  const signer = await getSigner(c.env.MLDSA_SEED)
  if (!signer) return c.json({ error: 'integrity_unavailable' }, 503)
  return c.json({
    alg: INTEGRITY_ALG,
    standard: 'NIST FIPS 204',
    keyId: signer.keyId,
    bundleVersion: BUNDLE_VERSION,
    context: 'easyclaim/decision/v1',
    publicKey: toBase64(signer.publicKey),
  })
})
