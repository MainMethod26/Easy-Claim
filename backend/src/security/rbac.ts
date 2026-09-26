import type { MiddlewareHandler } from 'hono'
import type { AppEnv, Role } from '../types'
import { writeAuditEvent } from './audit'

/** Function-level authorization: rejects actors whose role is not in `roles`. */
export function requireRole(...roles: Role[]): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    const actor = c.get('actor')
    if (!roles.includes(actor.role)) {
      await writeAuditEvent(c, {
        action: 'authz.role_denied',
        resourceType: 'route',
        resourceId: `${c.req.method} ${c.req.routePath}`,
        outcome: 'denied',
      })
      return c.json({ error: 'forbidden' }, 403)
    }
    await next()
  }
}
