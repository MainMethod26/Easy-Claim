import { Hono } from 'hono'
import { INSURER_ROLES, type AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { writeAuditEvent } from '../security/audit'
import { loadAuthorizedClaim, transitionClaim } from '../security/claimAccess'
import { MAIN_PATH, isClaimStage } from '../security/claimStateMachine'
import {
  appealSchema,
  claimIdParam,
  initiateClaimSchema,
  listQuerySchema,
  screeningSchema,
  validate,
  verifyEligibilitySchema,
} from '../security/validation'

// Customer-side claim routes. Insurer-side transitions live in claimsInsurer.ts.
const router = new Hono<AppEnv>()

const notFound = { error: 'not_found' } as const

async function findOwnedPolicy(db: D1Database, policyId: string, userId: string) {
  return db
    .prepare('SELECT id, status, tenant_id FROM policies WHERE id = ? AND user_id = ?')
    .bind(policyId, userId)
    .first<{ id: string; status: string; tenant_id: string | null }>()
}

// General status check
router.get('/status', (c) => c.json({ status: 'active' }))

// List claims visible to the actor: a customer sees their own, insurer staff see their tenant's.
router.get('/', validate('query', listQuerySchema), async (c) => {
  const actor = c.get('actor')
  const { limit } = c.req.valid('query')

  if (actor.role === 'CUSTOMER') {
    const { results } = await c.env.DB.prepare(
      `SELECT id, policy_id, tenant_id, stage, status, category, created_at, updated_at
       FROM claims WHERE user_id = ? ORDER BY created_at DESC, id LIMIT ?`
    )
      .bind(actor.id, limit)
      .all()
    return c.json({ claims: results })
  }

  if (INSURER_ROLES.includes(actor.role) && actor.tenantId !== null) {
    // Drafts are not yet shared with the insurer. user_id is a platform-wide customer id
    // and is not exposed to tenant staff (DECISION REQUIRED: per-tenant claimant reference).
    const { results } = await c.env.DB.prepare(
      `SELECT id, policy_id, tenant_id, stage, status, category, created_at, updated_at
       FROM claims WHERE tenant_id = ? AND stage <> 'Draft' ORDER BY created_at DESC, id LIMIT ?`
    )
      .bind(actor.tenantId, limit)
      .all()
    return c.json({ claims: results })
  }

  await writeAuditEvent(c, { action: 'authz.role_denied', resourceType: 'route', resourceId: 'GET /claims', outcome: 'denied' })
  return c.json({ error: 'forbidden' }, 403)
})

// Wizard Step 2: Verification Check
// Only policy ownership + Active status can be verified today. Identity and
// waiting-period checks are not implemented, so they are reported as null (unknown)
// rather than true.
router.post('/verify-eligibility', requireRole('CUSTOMER'), validate('json', verifyEligibilitySchema), async (c) => {
  const { policyId } = c.req.valid('json')
  const policy = await findOwnedPolicy(c.env.DB, policyId, c.get('actor').id)
  const isPolicyActive = policy?.status === 'Active'
  return c.json({
    verified: isPolicyActive,
    context: { isIdentityValid: null, isPolicyActive, waitingPeriodCleared: null },
  })
})

// Wizard Step 1: Initiate (Draft creation)
router.post('/initiate', requireRole('CUSTOMER'), validate('json', initiateClaimSchema), async (c) => {
  const actor = c.get('actor')
  const { policyId, category } = c.req.valid('json')

  const policy = await findOwnedPolicy(c.env.DB, policyId, actor.id)
  const reason = !policy
    ? 'policy_not_owned'
    : policy.status !== 'Active'
      ? 'policy_not_active'
      : policy.tenant_id === null
        ? 'policy_missing_tenant'
        : null
  if (!policy || reason) {
    await writeAuditEvent(c, {
      action: 'claim.initiate_rejected',
      resourceType: 'policy',
      resourceId: policyId,
      outcome: 'denied',
      details: { reason },
    })
    return c.json({ error: 'policy_not_eligible' }, 422)
  }

  // Unguessable ID (previously claim_${Date.now()}, which was enumerable).
  const claimId = `claim_${crypto.randomUUID()}`
  const now = new Date().toISOString()
  // tenant_id is copied from the policy's insurer, never taken from the client.
  await c.env.DB.prepare(
    `INSERT INTO claims (id, user_id, policy_id, tenant_id, stage, status, category, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'Draft', 'Pending', ?, ?, ?)`
  )
    .bind(claimId, actor.id, policyId, policy.tenant_id, category ?? null, now, now)
    .run()

  await writeAuditEvent(c, {
    action: 'claim.created',
    resourceType: 'claim',
    resourceId: claimId,
    outcome: 'success',
    details: { policyId, tenantId: policy.tenant_id },
  })
  return c.json({ status: 'draft_created', claimId }, 201)
})

// Wizard Step 3: Screening & Context
router.patch(
  '/:claimId/screening',
  requireRole('CUSTOMER'),
  validate('param', claimIdParam),
  validate('json', screeningSchema),
  async (c) => {
    const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'owner-write')
    if (!claim) return c.json(notFound, 404)

    if (claim.stage !== 'Draft' && claim.stage !== 'Info Needed') {
      return c.json({ error: 'claim_not_editable', stage: claim.stage }, 409)
    }

    const { causeOfLoss, incidentDate } = c.req.valid('json')
    // The stage precondition is repeated in SQL so a concurrent transition cannot slip in
    // between the read above and this write.
    const written = await c.env.DB.prepare(
      "UPDATE claims SET cause_of_loss = ?, incident_date = ?, updated_at = ? WHERE id = ? AND stage IN ('Draft', 'Info Needed')"
    )
      .bind(causeOfLoss, incidentDate, new Date().toISOString(), claim.id)
      .run()
    if (written.meta.changes !== 1) return c.json({ error: 'claim_not_editable' }, 409)
    await writeAuditEvent(c, {
      action: 'claim.screening_updated',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'success',
    })

    // Answering an information request sends the claim back into screening.
    if (claim.stage === 'Info Needed') {
      const t = await transitionClaim(c, claim, 'Screening')
      if (!t.ok) return c.json({ error: t.error }, t.status)
    }

    return c.json({ status: 'screening_updated', message: 'Cause of loss and context saved.' })
  }
)

// Wizard Step 4: Supporting Evidence (OCR Queue)
// NOTE: no file is accepted or stored yet (no storage binding exists). This only
// queues an event. See docs/security/EVIDENCE_SECURITY.md.
router.post('/:claimId/evidence-ocr', requireRole('CUSTOMER'), validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'owner-write')
  if (!claim) return c.json(notFound, 404)

  if (claim.stage !== 'Draft' && claim.stage !== 'Info Needed') {
    return c.json({ error: 'claim_not_editable', stage: claim.stage }, 409)
  }

  await c.env.CLAIM_EVENTS?.send({
    event: 'ClaimEvidenceUploaded',
    data: { claimId: claim.id, timestamp: new Date().toISOString() },
  })
  await writeAuditEvent(c, {
    action: 'claim.evidence_queued',
    resourceType: 'claim',
    resourceId: claim.id,
    outcome: 'success',
  })
  return c.json({ status: 'processing OCR', message: 'Documents queued for analysis' }, 202)
})

// Wizard Step 5: Submit for Review
router.post('/:claimId/submit', requireRole('CUSTOMER'), validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'owner-write')
  if (!claim) return c.json(notFound, 404)

  if (claim.stage === 'Draft' && (!claim.cause_of_loss || !claim.incident_date)) {
    return c.json({ error: 'screening_incomplete' }, 422)
  }

  const t = await transitionClaim(c, claim, 'Submitted')
  if (!t.ok) return c.json({ error: t.error }, t.status)

  await c.env.CLAIM_EVENTS?.send({
    event: 'ClaimSubmitted',
    data: { claimId: claim.id, timestamp: new Date().toISOString() },
  })
  return c.json({ status: 'submitted', message: 'Claim successfully submitted for decision.', claimId: claim.id })
})

// Timeline and Decision (For Step 6: Status & Tracking)
router.get('/:claimId/timeline', validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'read')
  if (!claim) return c.json(notFound, 404)

  const { results } = await c.env.DB.prepare(
    `SELECT occurred_at, details FROM audit_events
     WHERE resource_type = 'claim' AND resource_id = ? AND action = 'claim.stage_changed'
     ORDER BY occurred_at`
  )
    .bind(claim.id)
    .all<{ occurred_at: string; details: string }>()

  const reachedAt = new Map<string, string>()
  for (const row of results) {
    const to = (JSON.parse(row.details) as { to?: string }).to
    if (to) reachedAt.set(to, row.occurred_at)
  }

  // A stage counts as completed when the audit trail shows it was reached, or when the claim
  // is currently at or beyond it on the main path (seeded claims have no audit history).
  const currentIndex = MAIN_PATH.indexOf(claim.stage as (typeof MAIN_PATH)[number])
  return c.json({
    claimId: claim.id,
    currentStage: isClaimStage(claim.stage) ? claim.stage : 'Unknown',
    timeline: MAIN_PATH.map((stage, i) => ({
      stage,
      date: reachedAt.get(stage) ?? null,
      completed: reachedAt.has(stage) || (currentIndex >= 0 && i <= currentIndex),
    })),
  })
})

router.get('/:claimId/decision', validate('param', claimIdParam), async (c) => {
  const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'read')
  if (!claim) return c.json(notFound, 404)

  const decided = claim.stage === 'Decision' || claim.stage === 'Paid'
  return c.json({ decision: decided ? claim.status : 'pending' })
})

router.post(
  '/:claimId/appeal',
  requireRole('CUSTOMER'),
  validate('param', claimIdParam),
  validate('json', appealSchema),
  async (c) => {
    const claim = await loadAuthorizedClaim(c, c.req.valid('param').claimId, 'owner-write')
    if (!claim) return c.json(notFound, 404)

    // Only a rejected decision can be appealed.
    if (claim.stage !== 'Decision' || claim.status !== 'Rejected') {
      return c.json({ error: 'not_appealable' }, 409)
    }

    const t = await transitionClaim(c, claim, 'Appeal')
    if (!t.ok) return c.json({ error: t.error }, t.status)
    return c.json({ status: 'appealed' })
  }
)

export default router
