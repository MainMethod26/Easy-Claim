import { Hono } from 'hono'
import { bodyLimit } from 'hono/body-limit'
import { cors } from 'hono/cors'
import { HTTPException } from 'hono/http-exception'
import { secureHeaders } from 'hono/secure-headers'
import gateway from './endpoints/gateway'
import policy from './endpoints/policy'
import claims from './endpoints/claims'
import claimsInsurer from './endpoints/claimsInsurer'
import evidence from './endpoints/evidence'
import ocr from './endpoints/ocr'
import identity from './endpoints/identity'
import audit from './endpoints/audit'
import riskSignals from './screening/routes'
import { processQueueBatch } from './endpoints/ocr'
import { requireActor } from './security/actor'
import type { AppEnv } from './types'
import { swaggerUI } from '@hono/swagger-ui'
import openapiData from './openapi.json'

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
    allowHeaders: ['Content-Type', 'Authorization', 'Idempotency-Key'],
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'OPTIONS'],
    maxAge: 600,
  })
)
// JSON/API bodies stay capped at 64 KB; only an actual file upload (multipart/form-data,
// evidence routes) gets the larger cap. Dispatched by content-type, not by path, so this
// cannot be bypassed by posting a large multipart body to an unrelated JSON route.
const JSON_BODY_LIMIT = 64 * 1024
const EVIDENCE_BODY_LIMIT = 10 * 1024 * 1024 + 64 * 1024 // MAX_EVIDENCE_BYTES + form overhead
app.use('*', (c, next) => {
  const isMultipart = (c.req.header('content-type') ?? '').toLowerCase().startsWith('multipart/form-data')
  return bodyLimit({
    maxSize: isMultipart ? EVIDENCE_BODY_LIMIT : JSON_BODY_LIMIT,
    onError: (c) => c.json({ error: 'payload_too_large' }, 413),
  })(c, next)
})

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

// Swagger UI Endpoint
app.get('/swagger', swaggerUI({ url: '/openapi.json' }))
// Serve OpenAPI JSON
app.get('/openapi.json', (c) => {
  return c.json(openapiData)
})

app.route('/api/v1/client', gateway)
app.route('/api/v1/covers', policy)
app.route('/api/v1/claims', claims)
app.route('/api/v1/claims', claimsInsurer)
app.route('/api/v1/claims', evidence)
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
