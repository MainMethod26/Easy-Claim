import { Hono } from 'hono'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { loadAuthorizedClaim } from '../security/claimAccess'
import { claimIdParam, validate } from '../security/validation'
import { writeAuditEvent } from '../security/audit'
import { readRiskSignals, signalSummary } from './quantumSignal'

/**
 * Phase 4 (quantum track): GET /claims/:claimId/risk-signals
 *
 * Read-only. Insurer staff of the claim's tenant only (same order as every insurer route:
 * requireActor -> validate -> role gate -> loadAuthorizedClaim('insurer') -> read).
 * Customers get 403 (the signal is internal screening context; DECISION REQUIRED whether a
 * customer-facing explanation is ever shown). Unknown or other-tenant claims get 404.
 * There is no POST/PATCH/PUT counterpart anywhere in the API.
 */
const router = new Hono<AppEnv>()
const insurerOnly = requireRole('ASSESSOR', 'MANAGER')

router.get('/:claimId/risk-signals', insurerOnly, validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'insurer')
  if (!claim) return c.json({ error: 'not_found' }, 404)
  const riskSignals = await readRiskSignals(c.env.DB, claim.id)
  // Who looked at which signal (digest), so a later change to the stored row is detectable.
  await writeAuditEvent(c, {
    action: 'screening.signal_read',
    resourceType: 'claim',
    resourceId: claim.id,
    outcome: 'success',
    details: riskSignals ? signalSummary(riskSignals) : { band: null },
  })
  return c.json({ claimId: claim.id, stage: claim.stage, riskSignals })
})

export default router
