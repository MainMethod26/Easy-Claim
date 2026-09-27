/**
 * Realtime connection (WebSocket) for the app.
 *
 *   1. POST /api/v1/realtime/ticket  (normal bearer token) → a 60-second ticket
 *   2. GET  /api/v1/realtime/connect?ticket=…  (WebSocket upgrade)
 *
 * Browsers cannot put an Authorization header on a WebSocket, so the long-lived API token is never
 * placed in a URL: it is exchanged for a short ticket with its own audience. A ticket is not accepted
 * as an API token and an API token is not accepted as a ticket. On connect the ticket, the Origin (to
 * stop cross-site WebSocket hijacking) and the account (active, same role/insurer, not revoked) are
 * checked, then the socket joins exactly one audience: the customer's own channel, the insurer's staff
 * channel, or the platform channel.
 */
import { Hono } from 'hono'
import { sign, verify } from 'hono/jwt'
import type { AppEnv } from '../types'
import { JWT_ALG, accountRejection, validateClaims } from '../security/actor'
import { channelName, type Audience } from './publish'

export const TICKET_TTL_SECONDS = 60
const ticketAudience = (apiAudience: string) => `${apiAudience}#realtime`

/** Authenticated: issue a connection ticket for the signed-in actor. */
export const realtimeTicket = new Hono<AppEnv>()
realtimeTicket.post('/ticket', async (c) => {
  const actor = c.get('actor')
  const { JWT_SECRET: secret, JWT_ISSUER: iss, JWT_AUDIENCE: aud } = c.env
  if (!secret || !iss || !aud || !c.env.REALTIME) return c.json({ error: 'realtime_unavailable' }, 503)
  const account = await c.env.DB.prepare('SELECT token_version FROM users WHERE id = ?').bind(actor.id).first<{ token_version: number | null }>()
  const now = Math.floor(Date.now() / 1000)
  const ticket = await sign(
    { sub: actor.id, role: actor.role, tenant_id: actor.tenantId, ver: account?.token_version ?? 0, iss, aud: ticketAudience(aud), iat: now, exp: now + TICKET_TTL_SECONDS },
    secret.trim(),
    JWT_ALG
  )
  return c.json({ ticket, expiresIn: TICKET_TTL_SECONDS, path: '/api/v1/realtime/connect' })
})

/** Public (ticket-checked): the WebSocket upgrade. Mounted before the bearer-token middleware. */
export const realtimeConnect = new Hono<AppEnv>()
realtimeConnect.get('/connect', async (c) => {
  if (c.req.header('Upgrade')?.toLowerCase() !== 'websocket') return c.json({ error: 'upgrade_required' }, 426)
  const allowed = (c.env.ALLOWED_ORIGINS ?? '').split(',').map((o) => o.trim()).filter(Boolean)
  const origin = c.req.header('Origin')
  if (!origin || !allowed.includes(origin)) return c.json({ error: 'origin_not_allowed' }, 403)

  const { JWT_SECRET: secret, JWT_ISSUER: iss, JWT_AUDIENCE: aud } = c.env
  const ticket = c.req.query('ticket') ?? ''
  if (!secret || !iss || !aud || !c.env.REALTIME || !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(ticket)) {
    return c.json({ error: 'unauthenticated' }, 401)
  }
  let payload: Record<string, unknown>
  try {
    payload = (await verify(ticket, secret.trim(), { alg: JWT_ALG, iss, aud: ticketAudience(aud) })) as Record<string, unknown>
  } catch {
    return c.json({ error: 'unauthenticated' }, 401)
  }
  const now = Math.floor(Date.now() / 1000)
  const checked = validateClaims(payload, now)
  if (!checked.ok || (payload.exp as number) - now > TICKET_TTL_SECONDS || (await accountRejection(c.env.DB, checked.actor, payload.ver))) {
    return c.json({ error: 'unauthenticated' }, 401)
  }
  const actor = checked.actor
  const audience: Audience = actor.role === 'CUSTOMER' ? { user: actor.id } : actor.role === 'SUPERADMIN' ? { platform: true } : { tenant: actor.tenantId }
  const channel = channelName(audience)!
  const forward = new Request('https://realtime-hub/connect', { headers: { Upgrade: 'websocket', 'X-EC-User': actor.id } })
  return c.env.REALTIME.get(c.env.REALTIME.idFromName(channel)).fetch(forward)
})
