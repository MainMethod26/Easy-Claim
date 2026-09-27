import { Hono } from 'hono'
import { PolicyModel } from '../models/policyModel'
import type { AppEnv } from '../types'
import { requireRole } from '../security/rbac'
import { writeAuditEvent } from '../security/audit'
import {
  customerProfileSchema,
  linkRequestIdParam,
  linkRequestSchema,
  requestDocParam,
  tenantIdParam,
  validate,
} from '../security/validation'
import { getMyProfile, requirementsFor, resubmitRequest, saveMyProfile, uploadRequestDocument } from '../onboarding/customerOnboarding'
import { listInsurers, myLinkRequests, requestPolicyLink } from '../onboarding/service'

const router = new Hono<AppEnv>()


router.get('/my-covers', requireRole('CUSTOMER'), async (c) => {
  // Scoped to the authenticated actor (was hardcoded to 'user123').
  const policies = await PolicyModel.getMyCovers(c.env.DB, c.get('actor').id)
  return c.json({ policies })
})

// Policy linking: a customer who already holds a policy asks that insurer to link it (the insurer approves).
router.get('/insurers', requireRole('CUSTOMER'), async (c) => c.json({ insurers: await listInsurers(c.env.DB) }))

// Customer details shared with the insurers they apply to (ID number stored encrypted, shown masked).
router.get('/profile', requireRole('CUSTOMER'), async (c) => c.json(await getMyProfile(c)))

router.put('/profile', requireRole('CUSTOMER'), validate('json', customerProfileSchema), async (c) => {
  const r = await saveMyProfile(c, c.req.valid('json'))
  return r.ok ? c.json(r.value) : c.json({ error: r.error }, r.status)
})

/** What an insurer needs before it can approve a request. */
router.get('/insurers/:tenantId/requirements', requireRole('CUSTOMER'), validate('param', tenantIdParam), async (c) =>
  c.json({ requirements: await requirementsFor(c.env.DB, c.req.valid('param').tenantId) })
)

router.post('/link-requests/:requestId/documents/:docKey', requireRole('CUSTOMER'), validate('param', requestDocParam), async (c) => {
  const { requestId, docKey } = c.req.valid('param')
  const r = await uploadRequestDocument(c, requestId, docKey)
  return r.ok ? c.json({ documents: r.value }, 201) : c.json({ error: r.error }, r.status)
})

router.post('/link-requests/:requestId/resubmit', requireRole('CUSTOMER'), validate('param', linkRequestIdParam), async (c) => {
  const r = await resubmitRequest(c, c.req.valid('param').requestId)
  return r.ok ? c.json({ status: 'pending' }) : c.json({ error: r.error }, r.status)
})

router.get('/link-requests', requireRole('CUSTOMER'), async (c) => c.json({ requests: await myLinkRequests(c.env.DB, c.get('actor').id) }))

router.post('/link-requests', requireRole('CUSTOMER'), validate('json', linkRequestSchema), async (c) => {
  const { tenantId, policyNumber } = c.req.valid('json')
  const r = await requestPolicyLink(c, tenantId, policyNumber)
  return r.ok ? c.json({ request: r.value }, 201) : c.json({ error: r.error }, r.status)
})



export default router
