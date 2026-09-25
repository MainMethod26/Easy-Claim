import { Hono } from 'hono'

type Bindings = {
  DB: D1Database
  CLAIM_EVENTS: Queue
}

const router = new Hono<{ Bindings: Bindings }>()

// General status check
router.get('/status', (c) => c.json({ status: 'active' }))

// Wizard Step 2: Verification Check
router.post('/verify-eligibility', (c) => c.json({ 
  verified: true, 
  context: { isIdentityValid: true, isPolicyActive: true, waitingPeriodCleared: true } 
}))

// Wizard Step 1: Initiate (Draft creation)
router.post('/initiate', async (c) => {
  const claimId = `claim_${Date.now()}`;
  return c.json({ status: 'draft_created', claimId: claimId }, 201)
})

// Wizard Step 3: Screening & Context
router.patch('/:claimId/screening', async (c) => {
  return c.json({ status: 'screening_updated', message: 'Cause of loss and context saved.' })
})

// Wizard Step 4: Supporting Evidence (OCR Queue)
router.post('/:claimId/evidence-ocr', async (c) => {
  const claimId = c.req.param('claimId');
  const eventPayload = {
    event: 'ClaimEvidenceUploaded',
    data: { claimId, timestamp: new Date().toISOString() }
  };
  
  if (c.env.CLAIM_EVENTS) {
    await c.env.CLAIM_EVENTS.send(eventPayload);
  }
  
  return c.json({ status: 'processing OCR', message: 'Documents queued for analysis' }, 202)
})

// Wizard Step 5: Submit for Review
router.post('/:claimId/submit', async (c) => {
  const claimId = c.req.param('claimId');
  const eventPayload = {
    event: 'ClaimSubmitted',
    data: { claimId, timestamp: new Date().toISOString() }
  };
  
  if (c.env.CLAIM_EVENTS) {
    await c.env.CLAIM_EVENTS.send(eventPayload);
  }

  return c.json({ status: 'submitted', message: 'Claim successfully submitted for decision.', claimId })
})

// Timeline and Decision (For Step 6: Status & Tracking)
router.get('/:claimId/timeline', (c) => c.json({ 
  timeline: [
    { stage: 'Submitted', date: new Date().toISOString(), completed: true },
    { stage: 'Verified', date: new Date().toISOString(), completed: true },
    { stage: 'Review', date: null, completed: false }
  ] 
}))
router.get('/:claimId/decision', (c) => c.json({ decision: 'pending' }))
router.post('/:claimId/appeal', (c) => c.json({ status: 'appealed' }))

export default router
