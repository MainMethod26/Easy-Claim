import { Hono } from 'hono'
import { PolicyModel } from '../models/policyModel'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { writeAuditEvent } from '../security/audit'
import { joinRequestSchema, validate } from '../security/validation'

const router = new Hono<AppEnv>()

const MARKET_CATALOG = [
  { id: 'cat_01', provider: 'Discovery Health', name: 'Smart Plan', premium: 'R 2,450 / month' },
  { id: 'cat_02', provider: 'Sanlam', name: 'Comprehensive Life Cover', premium: 'R 850 / month' },
  { id: 'cat_03', provider: 'OUTsurance', name: 'Home & Contents Cover', premium: 'R 1,100 / month' },
  { id: 'cat_04', provider: 'Momentum', name: 'Ingwe Network Health', premium: 'R 540 / month' },
  { id: 'cat_05', provider: 'Old Mutual', name: 'Protect Family Funeral Plan', premium: 'R 150 / month' },
]

router.get('/my-covers', requireRole('CUSTOMER'), async (c) => {
  // Scoped to the authenticated actor (was hardcoded to 'user123').
  const policies = await PolicyModel.getMyCovers(c.env.DB, c.get('actor').id)
  return c.json({ policies })
})

router.get('/market-catalog', (c) => c.json({ catalog: MARKET_CATALOG }))

router.post('/join-request', requireRole('CUSTOMER'), validate('json', joinRequestSchema), async (c) => {
  const { planId } = c.req.valid('json')
  const plan = MARKET_CATALOG.find((p) => p.id === planId)
  if (!plan) return c.json({ error: 'unknown_plan' }, 422)

  await writeAuditEvent(c, {
    action: 'cover.join_requested',
    resourceType: 'catalog_plan',
    resourceId: plan.id,
    outcome: 'success',
  })
  // The request body is no longer echoed back; provider comes from the catalog, not the client.
  return c.json({ status: 'Requested', message: 'Join request forwarded to provider.', planId: plan.id, provider: plan.provider })
})

export default router
