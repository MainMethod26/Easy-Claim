import { Hono } from 'hono'
import type { Context } from 'hono'
import type { AppEnv, Role } from '../types'
import { writeAuditEvent } from '../security/audit'
import { requireRole } from '../security/rbac'
import { hashPassword } from '../security/password'
import {
  adminCreateUserSchema,
  createTenantSchema,
  tenantCreateUserSchema,
  tenantQuerySchema,
  userIdParam,
  userStatusSchema,
  validate,
} from '../security/validation'
import { findUserById, findUserByUsername, publicUser, type UserRow } from './auth'

/**
 * Platform and tenant administration (team role model, 26 Sep 2026).
 *
 * /api/v1/admin/*   SUPERADMIN only: insurers (tenants), insurer-admin accounts, platform statistics.
 *                   Read-only on claims (the claim routes enforce that). SUPERADMIN accounts are never
 *                   created or re-enabled through the API (bootstrap: scripts/seed-demo-users.mjs).
 * /api/v1/tenant/*  INSURER_ADMIN only: staff accounts (ASSESSOR, MANAGER, INSURER_ADMIN) and statistics
 *                   of its own tenant. The tenant is always the token's tenant_id; a tenantId in the body
 *                   is rejected.
 *
 * Every create/status change is audited. Password hashes never leave the database.
 */

const notFound = { error: 'not_found' } as const

const USER_COLUMNS = 'id, username, password_hash, role, tenant_id, display_name, status, created_at, created_by'

async function tenantExists(db: D1Database, id: string): Promise<boolean> {
  return (await db.prepare('SELECT 1 FROM tenants WHERE id = ?').bind(id).first()) !== null
}

async function listUsers(db: D1Database, where: string, binds: unknown[]) {
  const { results } = await db.prepare(`SELECT ${USER_COLUMNS} FROM users ${where} ORDER BY created_at, id`).bind(...binds).all<UserRow>()
  return results.map(publicUser)
}

async function createUser(
  c: Context<AppEnv>,
  input: { username: string; password: string; displayName: string; role: Role; tenantId: string | null },
  auditAction: string
) {
  const username = input.username.toLowerCase()
  if (await findUserByUsername(c.env.DB, username)) return c.json({ error: 'username_taken' }, 409)
  const user: UserRow = {
    id: `usr_${crypto.randomUUID()}`,
    username,
    password_hash: await hashPassword(input.password),
    role: input.role,
    tenant_id: input.tenantId,
    display_name: input.displayName,
    status: 'active',
    created_at: new Date().toISOString(),
    created_by: c.get('actor').id,
  }
  try {
    await c.env.DB.prepare(`INSERT INTO users (${USER_COLUMNS}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(user.id, user.username, user.password_hash, user.role, user.tenant_id, user.display_name, user.status, user.created_at, user.created_by)
      .run()
  } catch (err) {
    if (String(err).includes('UNIQUE')) return c.json({ error: 'username_taken' }, 409)
    throw err
  }
  await writeAuditEvent(c, {
    action: auditAction,
    resourceType: 'user',
    resourceId: user.id,
    outcome: 'success',
    details: { role: user.role, tenantId: user.tenant_id },
  })
  return c.json({ user: publicUser(user) }, 201)
}

async function setUserStatus(c: Context<AppEnv>, user: UserRow, status: 'active' | 'disabled', auditAction: string) {
  if (user.id === c.get('actor').id) return c.json({ error: 'cannot_change_own_status' }, 409)
  await c.env.DB.prepare('UPDATE users SET status = ? WHERE id = ?').bind(status, user.id).run()
  await writeAuditEvent(c, { action: auditAction, resourceType: 'user', resourceId: user.id, outcome: 'success', details: { status } })
  return c.json({ user: publicUser({ ...user, status }) })
}

async function claimsByStage(db: D1Database, tenantId: string | null) {
  const { results } = await db
    .prepare(
      `SELECT stage, count(*) AS n FROM claims WHERE stage <> 'Draft' AND (? IS NULL OR tenant_id = ?) GROUP BY stage`
    )
    .bind(tenantId, tenantId)
    .all<{ stage: string; n: number }>()
  const byStage: Record<string, number> = {}
  let total = 0
  for (const r of results) {
    byStage[r.stage] = r.n
    total += r.n
  }
  return { total, byStage }
}

// ---------------------------------------------------------------- SUPERADMIN

export const superadmin = new Hono<AppEnv>()
superadmin.use('*', requireRole('SUPERADMIN'))

superadmin.get('/tenants', async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT t.id, t.name,
            (SELECT count(*) FROM users u WHERE u.tenant_id = t.id) AS admin_count,
            (SELECT count(*) FROM policies p WHERE p.tenant_id = t.id) AS policy_count,
            (SELECT count(*) FROM claims cl WHERE cl.tenant_id = t.id AND cl.stage <> 'Draft') AS claim_count
     FROM tenants t ORDER BY t.name`
  ).all()
  return c.json({ tenants: results })
})

superadmin.post('/tenants', validate('json', createTenantSchema), async (c) => {
  const { id, name } = c.req.valid('json')
  if (await tenantExists(c.env.DB, id)) return c.json({ error: 'tenant_exists' }, 409)
  await c.env.DB.prepare('INSERT INTO tenants (id, name) VALUES (?, ?)').bind(id, name).run()
  await writeAuditEvent(c, { action: 'admin.tenant_created', resourceType: 'tenant', resourceId: id, outcome: 'success' })
  return c.json({ tenant: { id, name } }, 201)
})

superadmin.get('/users', validate('query', tenantQuerySchema), async (c) => {
  const { tenantId } = c.req.valid('query')
  const users = tenantId
    ? await listUsers(c.env.DB, 'WHERE tenant_id = ?', [tenantId])
    : await listUsers(c.env.DB, "WHERE role <> 'CUSTOMER'", [])
  return c.json({ users })
})

superadmin.post('/users', validate('json', adminCreateUserSchema), async (c) => {
  const body = c.req.valid('json')
  if (!(await tenantExists(c.env.DB, body.tenantId))) return c.json({ error: 'unknown_tenant' }, 422)
  return createUser(c, { ...body, role: 'INSURER_ADMIN', tenantId: body.tenantId }, 'admin.user_created')
})

superadmin.patch('/users/:userId', validate('param', userIdParam), validate('json', userStatusSchema), async (c) => {
  const user = await findUserById(c.env.DB, c.req.valid('param').userId)
  if (!user) return c.json(notFound, 404)
  // Platform accounts are managed outside the API; customers are not administered here.
  if (user.role === 'SUPERADMIN' && user.id !== c.get('actor').id) return c.json({ error: 'superadmin_managed_offline' }, 409)
  return setUserStatus(c, user, c.req.valid('json').status, 'admin.user_status_changed')
})

superadmin.get('/stats', async (c) => {
  const roles = await c.env.DB.prepare('SELECT role, count(*) AS n FROM users GROUP BY role').all<{ role: string; n: number }>()
  const usersByRole: Record<string, number> = {}
  for (const r of roles.results) usersByRole[r.role] = r.n
  const tenants = await c.env.DB.prepare('SELECT id, name FROM tenants ORDER BY name').all<{ id: string; name: string }>()
  const perTenant = []
  for (const t of tenants.results) perTenant.push({ tenantId: t.id, name: t.name, claims: await claimsByStage(c.env.DB, t.id) })
  return c.json({ tenants: tenants.results.length, usersByRole, claims: await claimsByStage(c.env.DB, null), perTenant })
})

// ---------------------------------------------------------------- INSURER_ADMIN (own tenant)

export const tenantAdmin = new Hono<AppEnv>()
tenantAdmin.use('*', requireRole('INSURER_ADMIN'))

tenantAdmin.get('/', async (c) => {
  const tenantId = c.get('actor').tenantId as string
  const tenant = await c.env.DB.prepare('SELECT id, name FROM tenants WHERE id = ?').bind(tenantId).first<{ id: string; name: string }>()
  return c.json({ tenant })
})

tenantAdmin.get('/users', async (c) => {
  return c.json({ users: await listUsers(c.env.DB, 'WHERE tenant_id = ?', [c.get('actor').tenantId]) })
})

tenantAdmin.post('/users', validate('json', tenantCreateUserSchema), async (c) => {
  const body = c.req.valid('json')
  return createUser(c, { ...body, tenantId: c.get('actor').tenantId }, 'tenant.user_created')
})

tenantAdmin.patch('/users/:userId', validate('param', userIdParam), validate('json', userStatusSchema), async (c) => {
  const user = await findUserById(c.env.DB, c.req.valid('param').userId)
  // Another tenant's admin is indistinguishable from a missing one.
  if (!user || user.tenant_id !== c.get('actor').tenantId) return c.json(notFound, 404)
  return setUserStatus(c, user, c.req.valid('json').status, 'tenant.user_status_changed')
})

tenantAdmin.get('/stats', async (c) => {
  return c.json({ tenantId: c.get('actor').tenantId, claims: await claimsByStage(c.env.DB, c.get('actor').tenantId) })
})
