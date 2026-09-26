import { describe, expect, it } from 'vitest'
import { admin, assessor, auditRows, call, customerA } from './helpers'

describe('function-level authorization (RBAC)', () => {
  it('customer cannot call the insurer OCR endpoint', async () => {
    const res = await call('/ocr/process', { method: 'POST', as: customerA })
    expect(res.status).toBe(403)
    expect(await auditRows('authz.role_denied')).not.toHaveLength(0)
  })

  it('assessor can call the OCR endpoint', async () => {
    expect((await call('/ocr/process', { method: 'POST', as: assessor })).status).toBe(200)
  })

  it('admin has no claim-reading powers', async () => {
    expect((await call('/claims/claim_disc_101/timeline', { as: admin })).status).toBe(404)
  })

  it.each([
    ['POST', '/claims/initiate'],
    ['POST', '/covers/join-request'],
    ['POST', '/profile/mandates/cancel'],
    ['GET', '/covers/my-covers'],
  ])('insurer roles cannot use customer-only %s %s', async (method, path) => {
    const json = method === 'GET' ? undefined : {}
    expect((await call(path, { method, as: assessor, json })).status).toBe(403)
  })
})
