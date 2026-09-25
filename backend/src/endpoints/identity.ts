import { Hono } from 'hono'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { writeAuditEvent } from '../security/audit'

// Stubs: none of these read or write real data yet. They now require an actor.
const router = new Hono<AppEnv>()
router.get('/', (c) => c.json({ profile: {} }))
router.patch('/', (c) => c.json({ updated: true }))
router.get('/consent', (c) => c.json({ consent: true }))
router.get('/mandates/:tenantId/check', (c) => c.json({ active: true }))
router.post('/mandates/cancel', requireRole('CUSTOMER'), async (c) => {
  await writeAuditEvent(c, { action: 'mandate.cancel_requested', resourceType: 'mandate', outcome: 'success' })
  return c.json({ cancelled: true })
})
export default router
