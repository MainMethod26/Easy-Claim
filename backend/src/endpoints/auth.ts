import { Hono } from 'hono'
import { sign } from 'hono/jwt'
import type { AppEnv, Role } from '../types'
import { writeAuditEvent } from '../security/audit'
import { JWT_ALG, MAX_TOKEN_TTL_SECONDS } from '../security/actor'
import { dummyHash, hashPassword, verifyPassword } from '../security/password'
import { insurerApplicationSchema, loginSchema, registerSchema, validate } from '../security/validation'
import { submitApplication } from '../onboarding/service'

/**
 * Accounts and sign-in (team role model, 26 Sep 2026).
 *
 * - POST /auth/login     username + password → short-lived HS256 token (the same token kind that
 *                        `requireActor` verifies everywhere else). Role and tenant come from the
 *                        users row, never from the client.
 * - POST /auth/register  self-service CUSTOMER account. Insurer admins and superadmins are created
 *                        by a SUPERADMIN (src/endpoints/admin.ts), never by registration.
 * - GET  /auth/me        the verified actor plus profile fields (mounted behind requireActor).
 *
 * Passwords are PBKDF2-SHA256 hashes (security/password.ts). Every attempt is audited without the
 * password. Unknown username and wrong password answer the same 401 after the same amount of work.
 *
 * KNOWN LIMITATIONS (hackathon): no token revocation (a disabled account keeps a valid token until
 * it expires, at most 1 h), no password reset, no MFA, single shared HS256 secret (BACKEND-SEC-019).
 */

export const TOKEN_TTL_SECONDS = 3600

export interface UserRow {
  id: string
  username: string
  password_hash: string
  role: Role
  tenant_id: string | null
  display_name: string
  status: 'active' | 'disabled'
  created_at: string
  created_by: string | null
}

export async function findUserByUsername(db: D1Database, username: string): Promise<UserRow | null> {
  return db.prepare('SELECT * FROM users WHERE username = ?').bind(username.toLowerCase()).first<UserRow>()
}

export async function findUserById(db: D1Database, id: string): Promise<UserRow | null> {
  return db.prepare('SELECT * FROM users WHERE id = ?').bind(id).first<UserRow>()
}

/** Public shape of a user: never the hash. */
export function publicUser(u: UserRow) {
  return {
    id: u.id,
    username: u.username,
    role: u.role,
    tenantId: u.tenant_id,
    displayName: u.display_name,
    status: u.status,
    createdAt: u.created_at,
  }
}

export async function issueToken(env: AppEnv['Bindings'], user: UserRow): Promise<{ token: string; expiresIn: number } | null> {
  if (!env.JWT_SECRET || !env.JWT_ISSUER || !env.JWT_AUDIENCE) return null
  const now = Math.floor(Date.now() / 1000)
  const expiresIn = Math.min(TOKEN_TTL_SECONDS, MAX_TOKEN_TTL_SECONDS[user.role])
  const payload: Record<string, string | number> = {
    sub: user.id,
    role: user.role,
    iss: env.JWT_ISSUER,
    aud: env.JWT_AUDIENCE,
    iat: now,
    exp: now + expiresIn,
  }
  if (user.tenant_id) payload.tenant_id = user.tenant_id
  return { token: await sign(payload, env.JWT_SECRET, JWT_ALG), expiresIn }
}

function sessionBody(user: UserRow, issued: { token: string; expiresIn: number }) {
  return { token: issued.token, tokenType: 'Bearer', expiresIn: issued.expiresIn, actor: publicUser(user) }
}

/** Public router (mounted before requireActor). */
export const authPublic = new Hono<AppEnv>()

authPublic.post('/login', validate('json', loginSchema), async (c) => {
  const { username, password } = c.req.valid('json')
  const user = await findUserByUsername(c.env.DB, username)
  // Same work for unknown users: verify against a dummy hash so timing does not reveal existence.
  const ok = user ? await verifyPassword(password, user.password_hash) : (await verifyPassword(password, await dummyHash()), false)

  if (!user || !ok || user.status !== 'active') {
    await writeAuditEvent(c, {
      action: 'auth.login',
      resourceType: 'user',
      resourceId: user?.id,
      outcome: 'denied',
      details: { reason: !user || !ok ? 'bad_credentials' : 'account_disabled' },
    })
    return c.json({ error: 'invalid_credentials' }, 401)
  }

  const issued = await issueToken(c.env, user)
  if (!issued) {
    console.error(`[${c.get('requestId')}] login: auth misconfigured`)
    return c.json({ error: 'auth_unavailable' }, 503)
  }
  await writeAuditEvent(c, {
    action: 'auth.login',
    resourceType: 'user',
    resourceId: user.id,
    outcome: 'success',
    details: { role: user.role, tenantId: user.tenant_id },
  })
  return c.json(sessionBody(user, issued))
})

authPublic.post('/register', validate('json', registerSchema), async (c) => {
  const body = c.req.valid('json')
  const username = body.username.toLowerCase()
  if (await findUserByUsername(c.env.DB, username)) {
    await writeAuditEvent(c, { action: 'auth.register', resourceType: 'user', outcome: 'denied', details: { reason: 'username_taken' } })
    return c.json({ error: 'username_taken' }, 409)
  }
  const user: UserRow = {
    id: `usr_${crypto.randomUUID()}`,
    username,
    password_hash: await hashPassword(body.password),
    role: 'CUSTOMER',
    tenant_id: null,
    display_name: body.displayName,
    status: 'active',
    created_at: new Date().toISOString(),
    created_by: null,
  }
  try {
    await c.env.DB.prepare(
      'INSERT INTO users (id, username, password_hash, role, tenant_id, display_name, status, created_at, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
    )
      .bind(user.id, user.username, user.password_hash, user.role, null, user.display_name, user.status, user.created_at, null)
      .run()
  } catch (err) {
    // Race on the UNIQUE(username) constraint.
    if (String(err).includes('UNIQUE')) return c.json({ error: 'username_taken' }, 409)
    throw err
  }
  const issued = await issueToken(c.env, user)
  if (!issued) return c.json({ error: 'auth_unavailable' }, 503)
  await writeAuditEvent(c, { action: 'auth.register', resourceType: 'user', resourceId: user.id, outcome: 'success', details: { role: 'CUSTOMER' } })
  return c.json(sessionBody(user, issued), 201)
})

/** Authenticated router (mounted after requireActor). */
export const authInfo = new Hono<AppEnv>()

authInfo.get('/me', async (c) => {
  const actor = c.get('actor')
  const user = await findUserById(c.env.DB, actor.id)
  return c.json({
    actor: {
      id: actor.id,
      role: actor.role,
      tenantId: actor.tenantId,
      // Profile fields exist only for accounts in the users table (offline-minted test tokens have none).
      username: user?.username ?? null,
      displayName: user?.display_name ?? null,
      status: user?.status ?? null,
    },
  })
})

/**
 * Public: an insurance company applies to join. Nothing is created until the platform operator approves
 * (POST /admin/applications/:id/approve). Per-IP rate limited like /login; open applications are capped.
 */
authPublic.post('/insurer-applications', validate('json', insurerApplicationSchema), async (c) => {
  const r = await submitApplication(c, c.req.valid('json'))
  if (!r.ok) return c.json({ error: r.error }, r.status)
  return c.json({ application: { id: r.value.id, status: r.value.status, companyName: r.value.companyName } }, 201)
})
