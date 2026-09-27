/**
 * Customer routes for POPIA consent forms (/api/v1/consents). Staff routes live with the subject they
 * belong to: /tenant/policy-requests/:id/consent and /claims/:id/consent.
 */
import { Hono } from 'hono'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { consentIdParam, consentResponseSchema, signConsentSchema, validate } from '../security/validation'
import { myConsent, myConsents, respondNo, signConsent } from './service'

export const consents = new Hono<AppEnv>()
consents.use('*', requireRole('CUSTOMER'))

consents.get('/', async (c) => c.json({ consents: await myConsents(c) }))

consents.get('/:consentId', validate('param', consentIdParam), async (c) => {
  const found = await myConsent(c, c.req.valid('param').consentId)
  return found ? c.json({ consent: found }) : c.json({ error: 'not_found' }, 404)
})

consents.post('/:consentId/sign', validate('param', consentIdParam), validate('json', signConsentSchema), async (c) => {
  const { fullName, password } = c.req.valid('json')
  const r = await signConsent(c, c.req.valid('param').consentId, { fullName, password })
  return r.ok ? c.json({ consent: r.value }) : c.json({ error: r.error }, r.status)
})

for (const action of ['decline', 'withdraw'] as const) {
  consents.post(`/:consentId/${action}`, validate('param', consentIdParam), validate('json', consentResponseSchema), async (c) => {
    const r = await respondNo(c, c.req.valid('param').consentId, action, c.req.valid('json').reason)
    return r.ok ? c.json({ consent: r.value }) : c.json({ error: r.error }, r.status)
  })
}
