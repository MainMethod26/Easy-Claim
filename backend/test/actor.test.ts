import { describe, expect, it } from 'vitest'
import { call, customerA } from './helpers'

describe('actor resolution (dev stub, fails closed)', () => {
  it('401 when no actor headers are sent', async () => {
    const res = await call('/covers/my-covers')
    expect(res.status).toBe(401)
    expect(await res.json()).toEqual({ error: 'unauthenticated' })
  })

  it('401 when the dev flag is off, even with actor headers', async () => {
    const res = await call('/covers/my-covers', { as: customerA, env: { ALLOW_DEV_ACTOR_HEADERS: undefined } })
    expect(res.status).toBe(401)
  })

  it('401 for an unknown role', async () => {
    const res = await call('/covers/my-covers', { as: { id: 'user123', role: 'SUPERUSER' } })
    expect(res.status).toBe(401)
  })

  it('401 for a malformed actor id', async () => {
    const res = await call('/covers/my-covers', { as: { id: "user123' OR 1=1 --", role: 'CUSTOMER' } })
    expect(res.status).toBe(401)
  })

  it.each([
    '/client/home',
    '/covers/market-catalog',
    '/claims/status',
    '/profile',
    '/activities/history',
    '/activities/audit-trail',
  ])('%s requires an actor', async (path) => {
    expect((await call(path)).status).toBe(401)
  })
})
