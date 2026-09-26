import { Hono } from 'hono'
import { bodyLimit } from 'hono/body-limit'
import { cors } from 'hono/cors'
import { HTTPException } from 'hono/http-exception'
import { secureHeaders } from 'hono/secure-headers'
import gateway from './endpoints/gateway'
import policy from './endpoints/policy'
import claims from './endpoints/claims'
import claimsInsurer from './endpoints/claimsInsurer'
import ocr from './endpoints/ocr'
import identity from './endpoints/identity'
import audit from './endpoints/audit'
import riskSignals from './screening/routes'
import { processQueueBatch } from './endpoints/ocr'
import { requireActor } from './security/actor'
import type { AppEnv } from './types'

const app = new Hono<AppEnv>()

// Request ids are always generated server-side (never taken from an inbound header)
// because they are persisted in the append-only audit trail as the correlation key.
app.use('*', async (c, next) => {
  const id = crypto.randomUUID()
  c.set('requestId', id)
  c.header('X-Request-Id', id)
  await next()
})
app.use('*', secureHeaders())
app.use(
  '*',
  cors({
    // Only explicitly configured origins; no wildcard.
    origin: (origin, c) => {
      const allowed = (c.env.ALLOWED_ORIGINS ?? '').split(',').map((o: string) => o.trim()).filter(Boolean)
      return allowed.includes(origin) ? origin : null
    },
    allowHeaders: ['Content-Type', 'Authorization'],
    allowMethods: ['GET', 'POST', 'PATCH', 'OPTIONS'],
    maxAge: 600,
  })
)
app.use('*', bodyLimit({ maxSize: 64 * 1024, onError: (c) => c.json({ error: 'payload_too_large' }, 413) }))

// Basic per-client rate limit (Workers Rate Limiting binding, see wrangler.toml).
// The binding is approximate and per-location by design; it is abuse throttling,
// not exact accounting.
app.use('/api/*', async (c, next) => {
  if (c.env.RATE_LIMITER) {
    const key = c.req.header('cf-connecting-ip') ?? 'unknown'
    const { success } = await c.env.RATE_LIMITER.limit({ key })
    if (!success) return c.json({ error: 'rate_limited' }, 429)
  }
  await next()
})

// Every API route requires a verified bearer token. See src/security/actor.ts.
app.use('/api/v1/*', requireActor)

// Second, per-actor limit after authentication (same binding, actor-keyed), so one
// credential cannot exhaust the API from many addresses.
app.use('/api/v1/*', async (c, next) => {
  if (c.env.RATE_LIMITER) {
    const actor = c.get('actor')
    const { success } = await c.env.RATE_LIMITER.limit({ key: `actor:${actor.role}:${actor.id}` })
    if (!success) return c.json({ error: 'rate_limited' }, 429)
  }
  await next()
})

app.route('/api/v1/client', gateway)
app.route('/api/v1/covers', policy)
app.route('/api/v1/claims', claims)
app.route('/api/v1/claims', claimsInsurer)
app.route('/api/v1/claims', riskSignals) // Phase 4: read-only advisory screening signal
app.route('/api/v1/ocr', ocr)
app.route('/api/v1/profile', identity)
app.route('/api/v1/activities', audit)

app.notFound((c) => c.json({ error: 'not_found' }, 404))

// Never return stack traces or internal messages to clients.
app.onError((err, c) => {
  if (err instanceof HTTPException && err.status < 500) {
    return c.json({ error: err.message || 'bad_request' }, err.status)
  }
  console.error(`[${c.get('requestId')}] Unhandled error:`, err)
  return c.json({ error: 'internal_error', requestId: c.get('requestId') }, 500)
})

export { app }

export default {
  fetch: app.fetch,
  async queue(batch: MessageBatch<unknown>, env: unknown): Promise<void> {
    await processQueueBatch(batch, env)
  },
}
