import { Hono } from 'hono'
import { sign } from 'hono/jwt'
import type { AppEnv } from '../types'

const devLogin = new Hono<AppEnv>()

devLogin.post('/', async (c) => {
  const body = await c.req.json().catch(() => ({}))
  const loginId = body.idNumber || body.email || ''
  
  const secret = c.env.JWT_SECRET
  const issuer = c.env.JWT_ISSUER
  const audience = c.env.JWT_AUDIENCE
  
  if (!secret || !issuer || !audience) {
    return c.json({ error: 'Auth not configured in env' }, 500)
  }

  // Parse dummy role and tenant based on input for dev
  let role = 'CUSTOMER'
  let tenant_id = undefined
  let id = 'user123'

  if (loginId.includes('assessor')) {
    role = 'ASSESSOR'
    tenant_id = 'ins_discovery'
    id = 'assessor_a1'
  } else if (loginId.includes('manager')) {
    role = 'MANAGER'
    tenant_id = 'ins_discovery'
    id = 'manager_a1'
  }

  const now = Math.floor(Date.now() / 1000)
  const exp = now + 3600 // 1 hour

  const payload: any = {
    sub: id,
    role,
    iss: issuer,
    aud: audience,
    iat: now,
    exp,
  }

  if (tenant_id) {
    payload.tenant_id = tenant_id
  }

  const token = await sign(payload, secret, 'HS256')

  return c.json({
    status: 'success',
    token,
    profile: {
      id,
      first_name: role,
      last_name: tenant_id || 'User',
      role,
      tenant_id
    }
  })
})

export default devLogin
