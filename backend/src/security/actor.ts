import type { Context, MiddlewareHandler } from 'hono'
import { ROLES, type Actor, type AppEnv, type Role } from '../types'

/**
 * Resolves the authenticated actor for a request.
 *
 * THIS IS NOT AUTHENTICATION. Real authentication is owned by the backend team
 * (see docs/security/BACKEND_SECURITY_HANDOFF.md, BACKEND-SEC-001). Replace the body
 * of this function with real token/session verification; everything downstream
 * (RBAC, ownership checks, state machine, audit) only depends on the returned Actor.
 *
 * Until then it fails closed: every /api/v1 request is rejected with 401, unless the
 * local-only flag ALLOW_DEV_ACTOR_HEADERS="true" is set (via .dev.vars), in which case
 * the X-Dev-Actor-Id / X-Dev-Actor-Role headers are trusted. Those headers are
 * trivially spoofable and exist only so authorization logic can be tested now.
 */
export async function resolveActor(c: Context<AppEnv>): Promise<Actor | null> {
  if (c.env.ALLOW_DEV_ACTOR_HEADERS !== 'true') return null

  const id = c.req.header('X-Dev-Actor-Id')?.trim()
  const role = c.req.header('X-Dev-Actor-Role')?.trim().toUpperCase()
  if (!id || !/^[A-Za-z0-9_-]{1,64}$/.test(id)) return null
  if (!role || !(ROLES as readonly string[]).includes(role)) return null
  return { id, role: role as Role }
}

export const requireActor: MiddlewareHandler<AppEnv> = async (c, next) => {
  const actor = await resolveActor(c)
  if (!actor) return c.json({ error: 'unauthenticated' }, 401)
  c.set('actor', actor)
  await next()
}
