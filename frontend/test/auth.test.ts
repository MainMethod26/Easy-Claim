import { env } from 'cloudflare:workers'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { assessorA, call, customerA, mintToken } from './helpers'

const b64u = (s: string) => btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

describe('authentication (Bearer JWT)', () => {
  it('AUTH-001 no token → 401 with WWW-Authenticate', async () => {
    const res = await call('/covers/my-covers')
    expect(res.status).toBe(401)
    expect(res.headers.get('www-authenticate')).toContain('Bearer')
  })

  it.each([
    ['empty bearer', 'Bearer '],
    ['not a JWT', 'Bearer not.a.jwt!'],
    ['two segments', 'Bearer abc.def'],
    ['four segments', 'Bearer YWJj.ZGVm.Z2hp.aWpr'],
    ['basic scheme', 'Basic dXNlcjpwYXNz'],
    ['raw token without scheme', 'abc.def.ghi'],
    ['garbage segments', 'Bearer YWJj.ZGVm.Z2hp'],
  ])('AUTH-002 malformed token (%s) → 401', async (_name, authorization) => {
    const res = await call('/covers/my-covers', { authorization })
    expect(res.status).toBe(401)
  })

  it('AUTH-002b header parsing: scheme without a space, two headers, and query-string tokens are rejected', async () => {
    const token = await mintToken(customerA)
    expect((await call('/covers/my-covers', { authorization: `Bearer${token}` })).status).toBe(401)
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}, Bearer ${token}` })).status).toBe(401)
    expect((await call(`/covers/my-covers?access_token=${token}`)).status).toBe(401)
    expect((await call('/covers/my-covers', { authorization: `Bearer\t${token}` })).status).toBe(200)
    expect((await call('/covers/my-covers', { authorization: `BEARER ${token}` })).status).toBe(200)
  })

  it('AUTH-003 expired token → 401', async () => {
    const token = await mintToken(customerA, { ttl: -10 })
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}` })).status).toBe(401)
  })

  it('AUTH-004 wrong signing key → 401', async () => {
    const token = await mintToken(customerA, { secret: 'another-secret-that-is-also-long-enough-0000' })
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}` })).status).toBe(401)
  })

  it('AUTH-004b tampered payload (role escalation) → 401', async () => {
    const token = await mintToken(customerA)
    const [h, p, s] = token.split('.')
    const claims = JSON.parse(atob(p.replace(/-/g, '+').replace(/_/g, '/')))
    const forged = `${h}.${b64u(JSON.stringify({ ...claims, role: 'MANAGER', tenant_id: 'ins_discovery' }))}.${s}`
    expect((await call('/claims/claim_disc_101/verify', { method: 'POST', authorization: `Bearer ${forged}` })).status).toBe(401)
  })

  it('AUTH-004c alg=none → 401 (rejected by the pinned algorithm, not merely by the header parser)', async () => {
    const now = Math.floor(Date.now() / 1000)
    const header = b64u(JSON.stringify({ alg: 'none', typ: 'JWT' }))
    const payload = b64u(
      JSON.stringify({ sub: 'user123', role: 'MANAGER', tenant_id: 'ins_discovery', iss: env.JWT_ISSUER, aud: env.JWT_AUDIENCE, iat: now - 60, exp: now + 300 })
    )
    // A non-empty signature segment so the token passes the Bearer shape check and reaches verify().
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    try {
      expect((await call('/claims', { authorization: `Bearer ${header}.${payload}.AAAA` })).status).toBe(401)
      expect(warn.mock.calls.flat().map(String).join('\n')).toMatch(/token rejected: Jwt(HeaderInvalid|AlgorithmMismatch)/)
      // The empty-signature variant is stopped even earlier, by the token shape check.
      expect((await call('/claims', { authorization: `Bearer ${header}.${payload}.` })).status).toBe(401)
    } finally {
      warn.mockRestore()
    }
  })

  it('AUTH-004d HS512 token against pinned HS256 → 401', async () => {
    const token = await mintToken(customerA, { alg: 'HS512' })
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}` })).status).toBe(401)
  })

  it('AUTH-005 valid token → authenticated actor', async () => {
    const res = await call('/covers/my-covers', { as: customerA })
    expect(res.status).toBe(200)
    const { policies } = (await res.json()) as { policies: { user_id: string }[] }
    expect(policies.every((p) => p.user_id === 'user123')).toBe(true)
  })

  it('AUTH-005b bearer scheme is case-insensitive, token is not', async () => {
    const token = await mintToken(customerA)
    expect((await call('/covers/my-covers', { authorization: `bearer ${token}` })).status).toBe(200)
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token.toUpperCase()}` })).status).toBe(401)
  })

  it.each([
    ['unknown role', { claims: { role: 'SUPERUSER' } }],
    ['missing role', { omit: ['role'] }],
    ['missing exp', { omit: ['exp'] }],
    ['missing sub', { omit: ['sub'] }],
    ['wrong issuer', { claims: { iss: 'someone-else' } }],
    ['missing issuer', { omit: ['iss'] }],
    ['wrong audience', { claims: { aud: 'other-api' } }],
    ['missing audience', { omit: ['aud'] }],
    ['nbf in the future', { claims: { nbf: Math.floor(Date.now() / 1000) + 600 } }],
    ['iat in the future', { claims: { iat: Math.floor(Date.now() / 1000) + 600 } }],
    ['missing iat', { omit: ['iat'] }],
    ['lifetime above the 24h customer maximum', { ttl: 24 * 3600 + 60 }],
    ['customer carrying a tenant', { claims: { tenant_id: 'ins_discovery' } }],
  ])('AUTH-006 rejects %s → 401', async (_name, opts) => {
    const token = await mintToken(customerA, opts)
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}` })).status).toBe(401)
  })

  it('AUTH-006b insurer token without tenant_id → 401', async () => {
    const token = await mintToken({ id: 'assessor_x', role: 'ASSESSOR' })
    expect((await call('/claims', { authorization: `Bearer ${token}` })).status).toBe(401)
  })

  it('AUTH-006c staff token with a lifetime above the 8h maximum → 401', async () => {
    const token = await mintToken(assessorA, { ttl: 8 * 3600 + 60 })
    expect((await call('/claims', { authorization: `Bearer ${token}` })).status).toBe(401)
    const ok = await mintToken(assessorA, { ttl: 8 * 3600 - 60 })
    expect((await call('/claims', { authorization: `Bearer ${ok}` })).status).toBe(200)
  })

  it('AUTH-007 audience may be an array containing the API', async () => {
    const token = await mintToken(assessorA, { claims: { aud: ['other', env.JWT_AUDIENCE] } })
    expect((await call('/claims', { authorization: `Bearer ${token}` })).status).toBe(200)
  })

  it('AUTH-008 token reuse after expiry → 401 (ATTACK-P1-009)', async () => {
    const token = await mintToken(customerA, { ttl: 60 })
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}` })).status).toBe(200)
    // Advance the clock past exp instead of sleeping (both hono verify() and validateClaims() read Date.now()).
    vi.useFakeTimers()
    try {
      vi.setSystemTime(Date.now() + 120_000)
      expect((await call('/covers/my-covers', { authorization: `Bearer ${token}` })).status).toBe(401)
    } finally {
      vi.useRealTimers()
    }
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}` })).status).toBe(200)
  })

  it('AUTH-009 missing or short JWT_SECRET fails closed even for a well-formed token', async () => {
    const token = await mintToken(customerA)
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}`, env: { JWT_SECRET: undefined } })).status).toBe(401)
    const short = 'short'
    const shortToken = await mintToken(customerA, { secret: short })
    expect((await call('/covers/my-covers', { authorization: `Bearer ${shortToken}`, env: { JWT_SECRET: short } })).status).toBe(401)
  })

  it('AUTH-010 missing issuer/audience configuration fails closed', async () => {
    const token = await mintToken(customerA)
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}`, env: { JWT_ISSUER: undefined } })).status).toBe(401)
    expect((await call('/covers/my-covers', { authorization: `Bearer ${token}`, env: { JWT_AUDIENCE: '' } })).status).toBe(401)
  })

  it('AUTH-011 dev actor headers never bypass authentication (ATTACK-P1-010)', async () => {
    const headers = { 'X-Dev-Actor-Id': 'manager_a1', 'X-Dev-Actor-Role': 'MANAGER' }
    expect((await call('/claims', { headers })).status).toBe(401)
    expect((await call('/claims', { headers, env: { ALLOW_DEV_ACTOR_HEADERS: 'true' } as never })).status).toBe(401)
    // and they do not override a real token's identity
    const res = await call('/claims/claim_disc_101/verify', { method: 'POST', as: customerA, headers })
    expect(res.status).toBe(403)
  })

  it('AUTH-012 401 responses reveal nothing about the token or the failure', async () => {
    const token = await mintToken(customerA, { secret: 'another-secret-that-is-also-long-enough-0000' })
    const res = await call('/covers/my-covers', { authorization: `Bearer ${token}` })
    const text = await res.text()
    expect(text).toBe('{"error":"unauthenticated"}')
    expect(text).not.toContain(token.slice(0, 20))
  })

  describe('AUTH-013 server logs never contain the token', () => {
    let warn: ReturnType<typeof vi.spyOn>
    let error: ReturnType<typeof vi.spyOn>
    beforeEach(() => {
      warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
      error = vi.spyOn(console, 'error').mockImplementation(() => {})
    })
    afterEach(() => {
      warn.mockRestore()
      error.mockRestore()
    })

    it.each([
      ['expired', { ttl: -10 }],
      ['bad signature', { secret: 'another-secret-that-is-also-long-enough-0000' }],
      ['wrong audience', { claims: { aud: 'other' } }],
      ['out-of-policy claims (customer with tenant)', { claims: { tenant_id: 'ins_discovery' } }],
    ])('for a %s token', async (_name, opts) => {
      const token = await mintToken(customerA, opts)
      expect((await call('/covers/my-covers', { authorization: `Bearer ${token}` })).status).toBe(401)
      const logged = [...warn.mock.calls, ...error.mock.calls].flat().map(String).join('\n')
      expect(logged).toMatch(/token rejected: (Jwt\w+|claims:[a-z_]+)/)
      expect(logged).not.toContain('eyJ')
      expect(logged).not.toContain(token.split('.')[2])
    })
  })

  it('AUTH-014 no audit row is written for unauthenticated requests (no pre-auth DB writes)', async () => {
    const before = (await env.DB.prepare('SELECT count(*) AS n FROM audit_events').first<{ n: number }>())!.n
    await call('/covers/my-covers')
    await call('/covers/my-covers', { authorization: `Bearer ${await mintToken(customerA, { ttl: -1 })}` })
    const after = (await env.DB.prepare('SELECT count(*) AS n FROM audit_events').first<{ n: number }>())!.n
    expect(after).toBe(before)
  })
})
