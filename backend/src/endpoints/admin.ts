import { Hono } from 'hono'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'

const router = new Hono<AppEnv>()

router.use('*', requireRole('ADMIN'))

// GET all tenants
router.get('/tenants', async (c) => {
  const { results } = await c.env.DB.prepare('SELECT id, name, created_at FROM tenants ORDER BY created_at DESC').all()
  return c.json({ tenants: results })
})

// CREATE a tenant
router.post('/tenants', async (c) => {
  const body = await c.req.json().catch(() => ({}))
  if (!body.name || typeof body.name !== 'string') {
    return c.json({ error: 'invalid_tenant_name' }, 400)
  }
  
  const id = `tenant_${crypto.randomUUID()}`
  const now = new Date().toISOString()
  
  await c.env.DB.prepare('INSERT INTO tenants (id, name, created_at) VALUES (?, ?, ?)')
    .bind(id, body.name, now)
    .run()
    
  return c.json({ status: 'created', tenant: { id, name: body.name, created_at: now } }, 201)
})

export default router
