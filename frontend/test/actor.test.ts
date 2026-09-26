import { describe, expect, it } from 'vitest'
import { actorFromClaims } from '../src/security/actor'
import { call, customerA } from './helpers'

// Phase 0 tested the dev-header stub here. Phase 1 removed that stub; every original
// assertion (fail closed with no credentials, unknown role rejected, malformed id rejected,
// every route requires an actor) is kept and now runs against the JWT mechanism, and the
// old dev headers are asserted to be ignored. Full token tests live in auth.test.ts.

describe('actor resolution (JWT, fails closed)', () => {
  it('401 when no credentials are sent', async () => {
    const res = await call('/covers/my-covers')
    expect(res.status).toBe(401)
    expect(await res.json()).toEqual({ error: 'unauthenticated' })
  })

  it('401 for the retired dev headers, with or without the old flag', async () => {
    const headers = { 'X-Dev-Actor-Id': 'user123', 'X-Dev-Actor-Role': 'CUSTOMER' }
    expect((await call('/covers/my-covers', { headers })).status).toBe(401)
    const flagged = await call('/covers/my-covers', {
      headers,
      env: { ALLOW_DEV_ACTOR_HEADERS: 'true' } as never,
    })
    expect(flagged.status).toBe(401)
  })

  it('401 for an unknown role in a correctly signed token', async () => {
    const res = await call('/covers/my-covers', { as: { id: 'user123', role: 'SUPERUSER' } })
    expect(res.status).toBe(401)
  })

  it('401 for a malformed actor id in a correctly signed token', async () => {
    const res = await call('/covers/my-covers', { as: { id: "user123' OR 1=1 --", role: 'CUSTOMER' } })
    expect(res.status).toBe(401)
  })

  it('accepts a valid token', async () => {
    expect((await call('/covers/my-covers', { as: customerA })).status).toBe(200)
  })

  it.each([
    '/client/home',
    '/covers/market-catalog',
    '/claims',
    '/claims/status',
    '/profile',
    '/activities/history',
    '/activities/audit-trail',
  ])('%s requires an actor', async (path) => {
    expect((await call(path)).status).toBe(401)
  })
})

describe('actorFromClaims (pure claim validation)', () => {
  const now = 1_800_000_000
  const base = { sub: 'user123', role: 'CUSTOMER', iat: now - 60, exp: now + 3600 }

  it('accepts a customer without tenant', () => {
    expect(actorFromClaims(base, now)).toEqual({ id: 'user123', role: 'CUSTOMER', tenantId: null })
  })

  it('accepts insurer staff with tenant', () => {
    expect(actorFromClaims({ ...base, sub: 'a1', role: 'ASSESSOR', tenant_id: 'ins_discovery' }, now)).toEqual({
      id: 'a1',
      role: 'ASSESSOR',
      tenantId: 'ins_discovery',
    })
  })

  it.each([
    ['missing exp', { sub: 'u', role: 'CUSTOMER', iat: now }],
    ['non-numeric exp', { ...base, exp: '9999999999' }],
    ['expired', { ...base, exp: now }],
    ['exp beyond the customer maximum (24h)', { ...base, exp: now + 24 * 3600 + 1 }],
    ['exp beyond the staff maximum (8h)', { ...base, role: 'MANAGER', tenant_id: 'ins_sanlam', exp: now + 8 * 3600 + 1 }],
    ['missing iat', { sub: 'u', role: 'CUSTOMER', exp: now + 60 }],
    ['missing sub', { role: 'CUSTOMER', iat: now, exp: now + 60 }],
    ['malformed sub', { ...base, sub: 'user 123' }],
    ['missing role', { sub: 'u', iat: now, exp: now + 60 }],
    ['unknown role', { ...base, role: 'ROOT' }],
    ['lower-case role', { ...base, role: 'customer' }],
    ['customer with tenant', { ...base, tenant_id: 'ins_discovery' }],
    ['assessor without tenant', { ...base, role: 'ASSESSOR' }],
    ['manager without tenant', { ...base, role: 'MANAGER' }],
    ['malformed tenant', { ...base, role: 'ASSESSOR', tenant_id: 'ins discovery' }],
    ['non-string tenant', { ...base, role: 'ASSESSOR', tenant_id: 42 }],
    ['null payload', null],
    ['string payload', 'sub=user123'],
  ])('rejects %s', (_name, payload) => {
    expect(actorFromClaims(payload, now)).toBeNull()
  })

  it('accepts a staff token at exactly the 8h maximum and a customer token at exactly 24h', () => {
    expect(actorFromClaims({ ...base, role: 'ASSESSOR', tenant_id: 't', exp: now + 8 * 3600 }, now)).not.toBeNull()
    expect(actorFromClaims({ ...base, exp: now + 24 * 3600 }, now)).not.toBeNull()
  })

  it('admin may omit tenant (DECISION REQUIRED: platform vs tenant admin)', () => {
    expect(actorFromClaims({ ...base, role: 'ADMIN' }, now)).toEqual({ id: 'user123', role: 'ADMIN', tenantId: null })
    expect(actorFromClaims({ ...base, role: 'ADMIN', tenant_id: 'ins_sanlam' }, now)?.tenantId).toBe('ins_sanlam')
  })
})
