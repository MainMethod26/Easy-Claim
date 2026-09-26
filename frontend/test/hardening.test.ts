import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { call, customerA } from './helpers'

describe('API hardening', () => {
  it('rejects oversized bodies with 413', async () => {
    const res = await call('/covers/join-request', {
      method: 'POST',
      as: customerA,
      json: { planId: 'cat_01', pad: 'x'.repeat(70 * 1024) },
    })
    expect(res.status).toBe(413)
  })

  it('sets security headers', async () => {
    const res = await call('/covers/market-catalog', { as: customerA })
    expect(res.headers.get('x-content-type-options')).toBe('nosniff')
    expect(res.headers.get('x-frame-options')).toBe('SAMEORIGIN')
    expect(res.headers.get('strict-transport-security')).toContain('max-age')
    expect(res.headers.get('x-request-id')).toBeTruthy()
  })

  it('CORS allows only configured origins', async () => {
    const good = await call('/covers/market-catalog', { as: customerA, headers: { Origin: 'http://localhost:5173' } })
    expect(good.headers.get('access-control-allow-origin')).toBe('http://localhost:5173')
    const bad = await call('/covers/market-catalog', { as: customerA, headers: { Origin: 'https://evil.example' } })
    expect(bad.headers.get('access-control-allow-origin')).toBeNull()
  })

  it('unknown routes return JSON 404', async () => {
    const res = await call('/does-not-exist', { as: customerA })
    expect(res.status).toBe(404)
    expect(await res.json()).toEqual({ error: 'not_found' })
  })

  it('malformed JSON returns 400', async () => {
    const res = await call('/claims/initiate', {
      method: 'POST',
      as: customerA,
      headers: { 'Content-Type': 'application/json' },
    })
    expect(res.status).toBe(400)
  })

  it('internal errors return a generic 500 without stack traces', async () => {
    const brokenDb = {
      prepare() {
        throw new Error('SQLITE_ERROR: secret internal detail at /src/models/policyModel.ts:3')
      },
    } as unknown as D1Database
    const res = await call('/covers/my-covers', { as: customerA, env: { DB: brokenDb } })
    expect(res.status).toBe(500)
    const text = await res.text()
    expect(text).not.toContain('SQLITE')
    expect(text).not.toContain('policyModel')
    expect(JSON.parse(text)).toMatchObject({ error: 'internal_error' })
  })

  it('returns 429 when the rate limiter denies the request', async () => {
    const denyAll = { limit: async () => ({ success: false }) } as unknown as RateLimit
    const res = await call('/covers/market-catalog', { as: customerA, env: { RATE_LIMITER: denyAll } })
    expect(res.status).toBe(429)
  })

  it('rate limits per IP before auth and per actor after auth', async () => {
    const keys: string[] = []
    const recording = { limit: async ({ key }: { key: string }) => ((keys.push(key), { success: true })) } as unknown as RateLimit
    await call('/covers/market-catalog', { as: customerA, env: { RATE_LIMITER: recording } })
    expect(keys).toEqual(['unknown', 'actor:CUSTOMER:user123'])

    // an authenticated actor over their own limit is refused even when the IP limit passes
    const denyActor = { limit: async ({ key }: { key: string }) => ({ success: !key.startsWith('actor:') }) } as unknown as RateLimit
    expect((await call('/covers/market-catalog', { as: customerA, env: { RATE_LIMITER: denyActor } })).status).toBe(429)
    // unauthenticated requests never reach the actor limiter
    keys.length = 0
    await call('/covers/market-catalog', { env: { RATE_LIMITER: recording } })
    expect(keys).toEqual(['unknown'])
  })

  it('rate limit binding is configured', () => {
    expect(env.RATE_LIMITER).toBeDefined()
  })
})
