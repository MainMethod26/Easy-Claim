import { Hono, type Context } from 'hono'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { messageStatement } from '../claims/messages'
import { writeAuditEvent } from '../security/audit'
import { loadAuthorizedClaim, transitionClaim, type ClaimRow } from '../security/claimAccess'
import { checkTransition, type ClaimStage } from '../security/claimStateMachine'
import { DECISION_RULES_VERSION, evidenceDigest, gatedInsert, latestDecision, payoutFor } from '../security/ledger'
import { claimIdParam, decideSchema, emptyBodySchema, requestInfoSchema, validate } from '../security/validation'
import { readRiskSignals, signalSummary } from '../screening/quantumSignal'
import { getSigner, signDecision, verifyDecision } from '../security/integrity'
import { applyProfileBanking } from '../onboarding/banking'
import { consentInsert, latestConsentDetail, publishConsent, sendConsent } from '../consent/service'

/**
 * Insurer-side claim operations. Each route is a thin wrapper: the state machine
 * (claimStateMachine.ts) decides whether the transition is legal and which role may perform
 * it; transitionClaim() is the only code path that changes a stage.
 *
 * Authorization order on every route:
 *   1. requireActor (index.ts)            – verified token (actor, tenant)
 *   2. coarse role gate (insurer roles)   – resource-independent, cannot leak claim data
 *   3. validate params/body               – strict schemas
 *   4. loadAuthorizedClaim('insurer')     – claim must belong to the actor's tenant, else 404
 *   5. state validation                   – checkTransition (edge + per-edge role)
 *   6. business validation                – Phase 3: amounts, destination, decision record
 *   7. transitionClaim                    – ONE D1 batch: stage change + audit + ledger rows
 *
 * Phase 3 (decision + payout): /decide records an insert-only decision (who/what/when/why,
 * amounts, destination snapshot); /pay is a SIMULATED payout — it pays only the recorded
 * approved amount to the destination snapshotted at decision time, once. No money moves.
 */
const router = new Hono<AppEnv>()
const insurerOnly = requireRole('ASSESSOR', 'MANAGER')
const notFound = { error: 'not_found' } as const

function respond(c: Context<AppEnv>, claimId: string, from: string, to: ClaimStage) {
  return c.json({ status: 'transitioned', claimId, from, to })
}

router.post('/:claimId/verify', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  // Documents checked: the customer's POPIA consent / claim mandate form is created in the same batch
  // (only if the stage change applies). Screening waits for the customer's signature.
  const form = await consentInsert(c, claimSubject(claim), true)
  const t = await transitionClaim(c, claim, 'Verified', { extra: [form.statement] })
  if (!t.ok) return c.json({ error: t.error }, t.status)
  publishConsent(c, { id: form.id, user_id: claim.user_id, tenant_id: claim.tenant_id as string, subject_type: 'claim', subject_id: claim.id }, 'pending')
  return c.json({ status: 'transitioned', claimId: claim.id, from: claim.stage, to: 'Verified', consentRequested: true })
})

function claimSubject(claim: { id: string; tenant_id: string | null; user_id: string }) {
  return {
    tenantId: claim.tenant_id as string,
    userId: claim.user_id,
    subjectType: 'claim' as const,
    subjectId: claim.id,
    subjectLabel: `claim ${claim.id.replace(/^claim_/, '').slice(0, 8).toUpperCase()}`,
  }
}

// Send (or re-send after a decline or withdrawal) the consent form for a claim whose documents are
// checked. Claims verified before consent forms existed get theirs this way. The insurer admin may send
// it too (a communication, not a claim decision: the admin still cannot move the claim).
router.post('/:claimId/consent', requireRole('ASSESSOR', 'MANAGER', 'INSURER_ADMIN'), validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'read')
  if (!claim) return c.json(notFound, 404)
  if (['Draft', 'Submitted', 'Withdrawn', 'Expired', 'Paid'].includes(claim.stage)) return c.json({ error: 'documents_not_checked' }, 409)
  const r = await sendConsent(c, claimSubject(claim))
  return r.ok ? c.json({ consent: r.value }, 201) : c.json({ error: r.error }, r.status)
})

// The latest consent form (full text and seal check) for the claim's tenant staff and its owner.
router.get('/:claimId/consent', validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'read')
  if (!claim) return c.json(notFound, 404)
  return c.json({ consent: await latestConsentDetail(c, 'claim', claim.id) })
})

router.post('/:claimId/screen', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  const t = await transitionClaim(c, claim, 'Screening')
  if (!t.ok) return c.json({ error: t.error }, t.status)
  // Phase 4: attach the advisory screening signal (read-only; null when none was computed).
  // It is context for the assessor and has no effect on the transition above.
  const riskSignals = await readRiskSignals(c.env.DB, claim.id)
  await writeAuditEvent(c, {
    action: 'screening.signal_attached',
    resourceType: 'claim',
    resourceId: claim.id,
    outcome: 'success',
    details: riskSignals ? signalSummary(riskSignals) : { band: null },
  })
  return c.json({ status: 'transitioned', claimId: claim.id, from: claim.stage, to: 'Screening', riskSignals })
})

// Screening → Review, and Appeal → Review (the latter is MANAGER-only in the state machine).
router.post('/:claimId/review', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  const t = await transitionClaim(c, claim, 'Review')
  if (!t.ok) return c.json({ error: t.error }, t.status)
  return respond(c, claim.id, claim.stage, 'Review')
})

// Screening | Review → Info Needed, with what is needed. The customer answers via POST /:claimId/respond
// (or by updating the details in the wizard). The message is stored with the transition, in one batch.
router.post('/:claimId/request-info', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  // Body is optional (older clients send none); when present it must match the schema exactly.
  const raw = (await c.req.text()).trim()
  let message: string | undefined
  if (raw) {
    let parsed: unknown
    try {
      parsed = JSON.parse(raw)
    } catch {
      return c.json({ error: 'validation_failed' }, 400)
    }
    const v = requestInfoSchema.safeParse(parsed)
    if (!v.success) return c.json({ error: 'validation_failed' }, 400)
    message = v.data.message
  }
  const t = await transitionClaim(c, claim, 'Info Needed', {
    details: { withMessage: !!message },
    extra: message ? [messageStatement(c, claim, 'info_request', message, true)] : [],
  })
  if (!t.ok) return c.json({ error: t.error }, t.status)
  return respond(c, claim.id, claim.stage, 'Info Needed')
})

/**
 * Review → Decision (MANAGER only). Records an insert-only decision in the same batch as
 * the stage change. For an approval the approved amount defaults to, and can never exceed,
 * the amount the customer claimed; the payout destination is snapshotted by hash.
 */
router.post('/:claimId/decide', insurerOnly, validate('param', claimIdParam), validate('json', decideSchema), async (c) => {
  const loaded = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!loaded) return c.json(notFound, 404)
  let claim: ClaimRow = loaded
  const actor = c.get('actor')
  const { outcome, reason, approvedAmountCents } = c.req.valid('json')

  // State validation first; transitionClaim produces the audited 403/409.
  const pre = checkTransition(claim.stage, 'Decision', actor.role)
  if (!pre.ok) {
    const t = await transitionClaim(c, claim, 'Decision', { status: outcome, details: { outcome } })
    return c.json({ error: t.ok ? 'unexpected' : t.error }, t.ok ? 500 : t.status)
  }

  // Business validation.
  const reject = async (reason: string, status: 422) => {
    await writeAuditEvent(c, {
      action: 'claim.decision_rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { outcome, reason },
    })
    return c.json({ error: reason }, status)
  }
  let approved: number | null = null
  if (outcome === 'Approved') {
    // Banking lives on the customer's profile: a claim submitted before the customer added it picks it up now.
    if (!claim.payout_destination_hash && (await applyProfileBanking(c.env.DB, claim.id, claim.user_id))) {
      claim = (await loadAuthorizedClaim(c, claim.id, 'insurer')) ?? claim
    }
    if (claim.claimed_amount_cents === null || !claim.payout_destination_hash) return reject('payout_details_missing', 422)
    approved = approvedAmountCents ?? claim.claimed_amount_cents
    if (approved > claim.claimed_amount_cents) return reject('amount_exceeds_claimed', 422)
  } else if (approvedAmountCents !== undefined) {
    return reject('amount_not_allowed_for_rejection', 422)
  }

  // Snapshot of the evidence set (Phase 2) the decision is taken on; null when there is none.
  const evidence = await evidenceDigest(c.env.DB, claim.id)
  // Phase 4: record the screening signal the decision-maker had (advisory context only; it is
  // never an input to any rule here). Null when no signal was computed.
  const screening = await readRiskSignals(c.env.DB, claim.id)

  // Phase 5: no decision is recorded unsigned. Missing/invalid MLDSA_SEED fails closed.
  const signer = await getSigner(c.env.MLDSA_SEED)
  if (!signer) {
    await writeAuditEvent(c, {
      action: 'claim.decision_rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'failure',
      details: { outcome, reason: 'integrity_unavailable' },
    })
    return c.json({ error: 'integrity_unavailable' }, 503)
  }

  const decisionId = `dec_${crypto.randomUUID()}`
  const fields = {
    id: decisionId,
    claim_id: claim.id,
    tenant_id: claim.tenant_id,
    outcome,
    reason,
    previous_stage: claim.stage,
    claimed_amount_cents: claim.claimed_amount_cents,
    approved_amount_cents: approved,
    destination_hash: claim.payout_destination_hash,
    actor_id: actor.id,
    actor_role: actor.role,
    decided_at: new Date().toISOString(),
    rules_version: DECISION_RULES_VERSION,
    evidence_digest: evidence.digest,
    risk_signal: screening ? JSON.stringify(signalSummary(screening)) : null,
  }
  // ML-DSA-65 signature over the canonical decision bundle, stored with the row in the same batch.
  const signature = await signDecision(signer, fields)
  const record = gatedInsert(c.env.DB, 'claim_decisions', {
    ...fields,
    request_id: c.get('requestId') ?? null,
    ...signature,
  })
  const t = await transitionClaim(c, claim, 'Decision', {
    status: outcome,
    details: { outcome, decisionId, approvedAmountCents: approved, evidenceCount: evidence.count },
    extra: [record],
  })
  if (!t.ok) return c.json({ error: t.error }, t.status)
  await writeAuditEvent(c, {
    action: 'claim.decision_recorded',
    resourceType: 'claim_decision',
    resourceId: decisionId,
    outcome: 'success',
    details: { claimId: claim.id, outcome, approvedAmountCents: approved, previousStage: claim.stage, evidenceCount: evidence.count, evidenceDigest: evidence.digest, integrityAlg: signature.integrity_alg, integrityKeyId: signature.integrity_key_id, bundleDigest: signature.integrity_bundle_digest },
  })
  return c.json({
    status: 'transitioned',
    claimId: claim.id,
    from: claim.stage,
    to: 'Decision',
    outcome,
    decisionId,
    approvedAmountCents: approved,
    evidenceCount: evidence.count,
    evidenceDigest: evidence.digest,
    integrity: { alg: signature.integrity_alg, keyId: signature.integrity_key_id, bundleDigest: signature.integrity_bundle_digest },
  })
})

/**
 * Decision → Paid (MANAGER only). SIMULATED payout: no request body is accepted (amount and
 * destination are never client-supplied); the amount comes from the recorded approved
 * decision, the destination must still hash to the value snapshotted at decision time, and
 * exactly one payout row can exist per claim. An optional Idempotency-Key header makes a
 * retried identical request return the same payout instead of an error.
 */
router.post('/:claimId/pay', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  const actor = c.get('actor')

  const blocked = async (reason: string, status: 400 | 409, extra: Record<string, string | number | null> = {}) => {
    await writeAuditEvent(c, {
      action: 'payout.blocked',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { reason, stage: claim.stage, ...extra },
    })
    return c.json({ error: reason }, status)
  }

  // A body is not part of this operation. Any client-supplied field (amount, destination,
  // state) is rejected before anything else happens.
  const rawBody = (await c.req.text()).trim()
  if (rawBody.length > 0) {
    let parsed: unknown
    try {
      parsed = JSON.parse(rawBody)
    } catch {
      return blocked('client_supplied_fields', 400)
    }
    const result = emptyBodySchema.safeParse(parsed)
    if (!result.success) {
      return blocked('client_supplied_fields', 400, {
        fields: Object.keys((parsed as Record<string, unknown>) ?? {}).join(','),
      })
    }
  }

  const idemHeader = c.req.header('Idempotency-Key')?.trim() ?? null
  if (idemHeader !== null && !/^[A-Za-z0-9_-]{1,128}$/.test(idemHeader)) return blocked('invalid_idempotency_key', 400)

  // Replay: a payout already exists for this claim.
  const existing = await payoutFor(c.env.DB, claim.id)
  if (existing) {
    if (idemHeader !== null && existing.idempotency_key === idemHeader) {
      await writeAuditEvent(c, {
        action: 'payout.replayed_idempotent',
        resourceType: 'payout',
        resourceId: existing.id,
        outcome: 'success',
        details: { claimId: claim.id },
      })
      return c.json({ status: 'already_paid', payoutId: existing.id, amountCents: existing.amount_cents, simulated: true })
    }
    return blocked('already_paid', 409, { payoutId: existing.id })
  }

  // State validation (edge + MANAGER role); transitionClaim produces the audited 403/409.
  const pre = checkTransition(claim.stage, 'Paid', actor.role)
  if (!pre.ok) {
    const t = await transitionClaim(c, claim, 'Paid')
    return c.json({ error: t.ok ? 'unexpected' : t.error }, t.ok ? 500 : t.status)
  }

  // Business validation: an approved, recorded decision whose destination snapshot still matches.
  if (claim.status !== 'Approved') return blocked('not_approved', 409)
  const decision = await latestDecision(c.env.DB, claim.id)
  if (!decision) return blocked('decision_record_missing', 409)
  // Phase 5: pay only a decision whose ML-DSA signature still verifies over the stored bundle.
  // Checked before reading any field of the decision, so tampering is reported as tampering.
  const integrity = await verifyDecision(c.env.MLDSA_SEED, decision)
  if (integrity.status !== 'VALID') {
    return blocked('decision_integrity_failed', 409, { decisionId: decision.id, integrity: integrity.status })
  }
  if (decision.outcome !== 'Approved') return blocked('decision_record_missing', 409)
  if (decision.approved_amount_cents === null || decision.approved_amount_cents <= 0) return blocked('amount_missing', 409)
  if (!decision.destination_hash || decision.destination_hash !== claim.payout_destination_hash || !claim.payout_account_last4) {
    return blocked('destination_mismatch', 409, { decisionId: decision.id })
  }


  // A real payment rail (an Ansa/Stripe integration was prototyped in scripts/maintenance/patch_*.mjs) is NOT
  // wired in: it must (1) record the payout row BEFORE calling the provider, keyed by the Idempotency-Key, so a
  // retry cannot pay twice, (2) send the real account reference, never the last 4 digits, and (3) add a
  // migration that allows a status other than 'simulated' (payouts.status CHECK). See docs/INTEGRATION_REPORT.md.

  const payoutId = `pay_${crypto.randomUUID()}`
  const row = gatedInsert(c.env.DB, 'payouts', {
    id: payoutId,
    claim_id: claim.id,
    tenant_id: claim.tenant_id,
    decision_id: decision.id,
    amount_cents: decision.approved_amount_cents,
    destination_hash: decision.destination_hash,
    destination_last4: claim.payout_account_last4,
    status: 'simulated',
    idempotency_key: idemHeader,
    initiated_by: actor.id,
    initiated_role: actor.role,
    initiated_at: new Date().toISOString(),
    request_id: c.get('requestId') ?? null,
  })
  const t = await transitionClaim(c, claim, 'Paid', {
    details: { payoutId, decisionId: decision.id, amountCents: decision.approved_amount_cents },
    extra: [row],
  })
  if (!t.ok) return c.json({ error: t.error }, t.status)

  await writeAuditEvent(c, {
    action: 'payout.completed_simulated',
    resourceType: 'payout',
    resourceId: payoutId,
    outcome: 'success',
    details: { claimId: claim.id, decisionId: decision.id, amountCents: decision.approved_amount_cents },
  })
  return c.json({
    status: 'paid',
    simulated: true,
    claimId: claim.id,
    payoutId,
    decisionId: decision.id,
    amountCents: decision.approved_amount_cents,
    destination: { bankName: claim.payout_bank_name, accountLast4: claim.payout_account_last4 },
  })
})

export default router
