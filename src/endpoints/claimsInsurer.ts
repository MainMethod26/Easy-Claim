import { Hono, type Context } from 'hono'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { writeAuditEvent } from '../security/audit'
import { loadAuthorizedClaim, transitionClaim } from '../security/claimAccess'
import { checkTransition, type ClaimStage } from '../security/claimStateMachine'
import { claimIdParam, decideSchema, validate } from '../security/validation'

/**
 * Insurer-side claim operations (Phase 1). Each route is a thin wrapper: the state machine
 * (claimStateMachine.ts) decides whether the transition is legal and which role may perform
 * it; transitionClaim() is the only code path that changes a stage.
 *
 * Authorization order on every route:
 *   1. requireActor (index.ts)            – verified token
 *   2. validate params/body               – strict schemas
 *   3. coarse role gate (insurer roles)   – resource-independent, cannot leak claim data
 *   4. loadAuthorizedClaim('insurer')     – claim must belong to the actor's tenant, else 404
 *   5. transitionClaim                    – legal edge + per-transition role, conditional UPDATE
 *   6. audit event                        – written by transitionClaim / loadAuthorizedClaim
 *
 * Not implemented here (out of scope for Phase 1, see DECISION_SECURITY.md / PAYOUT_SECURITY.md):
 * decision records with amounts/reasons, screening rules, payment execution. `/pay` is a
 * state transition only; no money moves.
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
  const t = await transitionClaim(c, claim, 'Verified')
  if (!t.ok) return c.json({ error: t.error }, t.status)
  return respond(c, claim.id, claim.stage, 'Verified')
})

router.post('/:claimId/screen', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  const t = await transitionClaim(c, claim, 'Screening')
  if (!t.ok) return c.json({ error: t.error }, t.status)
  return respond(c, claim.id, claim.stage, 'Screening')
})

// Screening → Review, and Appeal → Review (the latter is MANAGER-only in the state machine).
router.post('/:claimId/review', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  const t = await transitionClaim(c, claim, 'Review')
  if (!t.ok) return c.json({ error: t.error }, t.status)
  return respond(c, claim.id, claim.stage, 'Review')
})

// Screening | Review → Info Needed. The customer answers via PATCH /:claimId/screening.
router.post('/:claimId/request-info', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  const t = await transitionClaim(c, claim, 'Info Needed')
  if (!t.ok) return c.json({ error: t.error }, t.status)
  return respond(c, claim.id, claim.stage, 'Info Needed')
})

// Review → Decision. The outcome becomes claims.status ('Approved' | 'Rejected').
router.post('/:claimId/decide', insurerOnly, validate('param', claimIdParam), validate('json', decideSchema), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)
  const { outcome } = c.req.valid('json')
  const t = await transitionClaim(c, claim, 'Decision', { status: outcome, details: { outcome } })
  if (!t.ok) return c.json({ error: t.error }, t.status)
  return c.json({ status: 'transitioned', claimId: claim.id, from: claim.stage, to: 'Decision', outcome })
})

// Decision → Paid. MANAGER-only (state machine) and only for an approved decision.
// This records the transition; it does not execute a payment.
router.post('/:claimId/pay', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json(notFound, 404)

  // Role and legality first (audited by transitionClaim), then the approval precondition.
  const pre = checkTransition(claim.stage, 'Paid', c.get('actor').role)
  if (pre.ok && claim.status !== 'Approved') {
    await writeAuditEvent(c, {
      action: 'claim.transition_rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { from: claim.stage, to: 'Paid', reason: 'not_approved' },
    })
    return c.json({ error: 'not_approved' }, 409)
  }

  const t = await transitionClaim(c, claim, 'Paid')
  if (!t.ok) return c.json({ error: t.error }, t.status)
  return respond(c, claim.id, claim.stage, 'Paid')
})

export default router
