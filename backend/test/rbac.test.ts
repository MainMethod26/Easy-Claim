import { describe, expect, it } from 'vitest'
import { assessorA, auditRows, call, customerA, insurerAdminA, managerA, superadmin } from './helpers'

describe('function-level authorization (RBAC)', () => {
  it('a customer calling a staff-only route is refused and the refusal is audited', async () => {
    const res = await call('/claims/claim_disc_101/verify', { method: 'POST', as: customerA })
    expect(res.status).toBe(403)
    expect(await auditRows('authz.role_denied')).not.toHaveLength(0)
  })

  it.each([
    ['POST', '/ocr/process'],
    ['GET', '/client/home'],
    ['GET', '/client/notifications'],
    ['GET', '/profile'],
    ['POST', '/profile/mandates/cancel'],
    ['GET', '/activities/audit-trail'],
    ['GET', '/covers/market-catalog'],
    ['POST', '/covers/join-request'],
    ['GET', '/claims/status'],
  ])('removed stub %s %s answers 404 (no fake data)', async (method, path) => {
    for (const who of [customerA, assessorA, managerA]) {
      expect((await call(path, { method, as: who, json: method === 'GET' ? undefined : {} })).status).toBe(404)
    }
  })

  it('insurer admin reads its tenant claim but has no claim actions and no screening signal', async () => {
    expect((await call('/claims/claim_disc_101', { as: insurerAdminA })).status).toBe(200)
    expect((await call('/claims/claim_disc_101/review', { method: 'POST', as: insurerAdminA })).status).toBe(403)
    expect((await call('/claims/claim_disc_101/risk-signals', { as: insurerAdminA })).status).toBe(403)
    expect((await call('/claims/claim_disc_101/risk-signals', { as: assessorA })).status).toBe(200)
  })

  it('superadmin neither reads a claim nor acts on it (platform operator)', async () => {
    expect((await call('/claims/claim_disc_101/timeline', { as: superadmin })).status).toBe(404)
    expect((await call('/claims/claim_disc_101/review', { method: 'POST', as: superadmin })).status).toBe(403)
    expect((await call('/claims/claim_disc_101/risk-signals', { as: superadmin })).status).toBe(403)
  })

  it.each([
    ['POST', '/claims/initiate'],
    ['GET', '/covers/my-covers'],
    ['PUT', '/covers/profile'],
    ['POST', '/covers/link-requests'],
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
