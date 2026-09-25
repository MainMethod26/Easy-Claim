import { Hono } from 'hono'
import { PolicyModel } from '../models/policyModel'
const router = new Hono<{ Bindings: { DB: D1Database } }>()

router.get('/my-covers', async (c) => {
  // Hardcoding 'user123' for now to match the seeded DB data
  const policies = await PolicyModel.getMyCovers(c.env.DB, 'user123')
  return c.json({ policies })
})

router.get('/market-catalog', (c) => c.json({ 
  catalog: [
    { id: 'cat_01', provider: 'Discovery Health', name: 'Smart Plan', premium: 'R 2,450 / month' },
    { id: 'cat_02', provider: 'Sanlam', name: 'Comprehensive Life Cover', premium: 'R 850 / month' },
    { id: 'cat_03', provider: 'OUTsurance', name: 'Home & Contents Cover', premium: 'R 1,100 / month' },
    { id: 'cat_04', provider: 'Momentum', name: 'Ingwe Network Health', premium: 'R 540 / month' },
    { id: 'cat_05', provider: 'Old Mutual', name: 'Protect Family Funeral Plan', premium: 'R 150 / month' }
  ]
}))

router.post('/join-request', async (c) => {
  const body = await c.req.json()
  return c.json({ status: 'Requested', message: 'Join request forwarded to provider.', body })
})

export default router
