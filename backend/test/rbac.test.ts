import { describe, expect, it } from 'vitest'
import { assessorA, auditRows, call, customerA, insurerAdminA, managerA, superadmin } from './helpers'

describe('function-level authorization (RBAC)', () => {
  it('customer cannot call the insurer OCR endpoint', async () => {
    const res = await call('/ocr/process', { method: 'POST', as: customerA })
    expect(res.status).toBe(403)
    expect(await auditRows('authz.role_denied')).not.toHaveLength(0)
  })

  it('assessor and manager can call the OCR endpoint; the insurer admin cannot', async () => {
    expect((await call('/ocr/process', { method: 'POST', as: assessorA })).status).toBe(200)
    expect((await call('/ocr/process', { method: 'POST', as: managerA })).status).toBe(200)
    expect((await call('/ocr/process', { method: 'POST', as: insurerAdminA })).status).toBe(403)
  })

  it('insurer admin reads its tenant claim but has no claim actions and no screening signal', async () => {
    expect((await call('/claims/claim_disc_101', { as: insurerAdminA })).status).toBe(200)
    expect((await call('/claims/claim_disc_101/review', { method: 'POST', as: insurerAdminA })).status).toBe(403)
    expect((await call('/claims/claim_disc_101/risk-signals', { as: insurerAdminA })).status).toBe(403)
    expect((await call('/claims/claim_disc_101/risk-signals', { as: assessorA })).status).toBe(200)
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
  ])('insurer staff and insurer admin cannot use customer-only %s %s', async (method, path) => {
    const json = method === 'GET' ? undefined : {}
    for (const who of [assessorA, managerA, insurerAdminA]) expect((await call(path, { method, as: who, json })).status).toBe(403)
  })

  it.each([
    ['POST', '/claims/initiate'],
    ['GET', '/covers/my-covers'],
  ])('superadmin cannot use customer-only %s %s', async (method, path) => {
    const json = method === 'GET' ? undefined : {}
    expect((await call(path, { method, as: superadmin, json })).status).toBe(403)
  })
})
