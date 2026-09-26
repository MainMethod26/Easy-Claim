import { describe, expect, it } from 'vitest'
import { auditRows, call, customerA, insurerA, superadmin } from './helpers'

describe('function-level authorization (RBAC)', () => {
  it('customer cannot call the insurer OCR endpoint', async () => {
    const res = await call('/ocr/process', { method: 'POST', as: customerA })
    expect(res.status).toBe(403)
    expect(await auditRows('authz.role_denied')).not.toHaveLength(0)
  })

  it('insurer admin can call the OCR endpoint', async () => {
    expect((await call('/ocr/process', { method: 'POST', as: insurerA })).status).toBe(200)
  })

  it('superadmin cannot call the insurer OCR endpoint', async () => {
    expect((await call('/ocr/process', { method: 'POST', as: superadmin })).status).toBe(403)
  })

  it('superadmin reads a submitted claim (platform read-only) but has no claim actions', async () => {
    expect((await call('/claims/claim_disc_101/timeline', { as: superadmin })).status).toBe(200)
    expect((await call('/claims/claim_disc_101/review', { method: 'POST', as: superadmin })).status).toBe(403)
    expect((await call('/claims/claim_disc_101/risk-signals', { as: superadmin })).status).toBe(403)
  })

  it.each([
    ['POST', '/claims/initiate'],
    ['POST', '/covers/join-request'],
    ['POST', '/profile/mandates/cancel'],
    ['GET', '/covers/my-covers'],
  ])('insurer admin cannot use customer-only %s %s', async (method, path) => {
    const json = method === 'GET' ? undefined : {}
    expect((await call(path, { method, as: insurerA, json })).status).toBe(403)
  })

  it.each([
    ['POST', '/claims/initiate'],
    ['GET', '/covers/my-covers'],
  ])('superadmin cannot use customer-only %s %s', async (method, path) => {
    const json = method === 'GET' ? undefined : {}
    expect((await call(path, { method, as: superadmin, json })).status).toBe(403)
  })
})
