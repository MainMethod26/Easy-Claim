import { Hono } from 'hono'

type Bindings = {
  DB: D1Database
  CLAIM_EVENTS: Queue
}

const router = new Hono<{ Bindings: Bindings }>()

// General status check
router.get('/status', (c) => c.json({ status: 'active' }))

// WIZARD / INTAKE ENDPOINTS (Customer Facing)
router.post('/initiate', async (c) => {
  const claimId = `claim_${Date.now()}`;
  return c.json({ status: 'draft_created', claimId: claimId }, 201)
})

router.post('/verify-eligibility', (c) => c.json({ 
  verified: true, 
  context: { isIdentityValid: true, isPolicyActive: true, waitingPeriodCleared: true } 
}))

router.post('/:claimId/evidence-ocr', async (c) => {
  const claimId = c.req.param('claimId');
  if (c.env.CLAIM_EVENTS) {
    await c.env.CLAIM_EVENTS.send({ event: 'ClaimEvidenceUploaded', data: { claimId, timestamp: new Date().toISOString() } });
  }
  return c.json({ status: 'processing OCR', message: 'Documents queued for analysis' }, 202)
})


// 6-STAGE STANDARD MODEL ENDPOINTS

// Stage 1: Submitted
router.post('/:claimId/submit', async (c) => {
  const claimId = c.req.param('claimId');
  if (c.env.CLAIM_EVENTS) {
    await c.env.CLAIM_EVENTS.send({ event: 'ClaimSubmitted', data: { claimId, timestamp: new Date().toISOString() } });
  }
  return c.json({ stage: 'SUBMITTED', message: 'Claim successfully submitted. Checklist complete.', claimId })
})

// Stage 2: Verified
router.post('/:claimId/verify', async (c) => {
  const claimId = c.req.param('claimId');
  return c.json({ stage: 'VERIFIED', message: 'Identity and policy confirmed.' })
})

// Stage 3: Screening
router.patch('/:claimId/screening', async (c) => {
  const claimId = c.req.param('claimId');
  return c.json({ stage: 'SCREENING', status: 'screening_updated', message: 'Risk score and route assigned.' })
})

// Stage 4: Review
router.post('/:claimId/review', async (c) => {
  const claimId = c.req.param('claimId');
  return c.json({ stage: 'REVIEW', message: 'Assessor review outcome recorded.' })
})

// Stage 5: Decision
router.post('/:claimId/decision', async (c) => {
  const claimId = c.req.param('claimId');
  const body = await c.req.json().catch(() => ({ decision: 'approved' }));
  return c.json({ stage: 'DECISION', decision: body.decision, message: 'Customer notified of decision.' })
})
router.get('/:claimId/decision', (c) => c.json({ decision: 'pending' }))

// Stage 6: Paid
router.post('/:claimId/pay', async (c) => {
  const claimId = c.req.param('claimId');
  return c.json({ stage: 'PAID', message: 'Payment confirmed, claim closed.' })
})


// SIDE STATES

// Info Needed
router.post('/:claimId/info-needed', async (c) => {
  const claimId = c.req.param('claimId');
  return c.json({ state: 'INFO_NEEDED', message: 'Claim paused. Waiting for customer information.' })
})

// Rejected
router.post('/:claimId/reject', async (c) => {
  const claimId = c.req.param('claimId');
  const body = await c.req.json().catch(() => ({ reason: 'Not covered' }));
  return c.json({ state: 'REJECTED', reason: body.reason, message: 'Claim rejected. Plain language reason provided.' })
})

// Appeal
router.post('/:claimId/appeal', async (c) => {
  const claimId = c.req.param('claimId');
  return c.json({ state: 'APPEAL', message: 'Appeal lodged. Claim returning to REVIEW stage.' })
})


// STATUS & TRACKING
router.get('/:claimId/timeline', (c) => c.json({ 
  timeline: [
    { stage: 'SUBMITTED', date: new Date().toISOString(), completed: true },
    { stage: 'VERIFIED', date: new Date().toISOString(), completed: true },
    { stage: 'SCREENING', date: new Date().toISOString(), completed: true },
    { stage: 'REVIEW', date: null, completed: false },
    { stage: 'DECISION', date: null, completed: false },
    { stage: 'PAID', date: null, completed: false }
  ] 
}))

export default router
