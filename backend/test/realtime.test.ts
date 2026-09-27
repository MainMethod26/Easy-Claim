import { describe, expect, it } from 'vitest'
import {
  assessorA,
  assessorB,
  call,
  createSubmittedClaim,
  customerA,
  customerB,
  insurerAdminA,
  mintToken,
  signClaimConsent,
  type TestActor,
} from './helpers'

// Live updates (src/realtime): a short ticket opens a WebSocket to exactly one audience (the customer,
// the insurer's staff, or the platform). Changes publish small notices (ids, stage, status only).

const ORIGIN = 'http://localhost:5173' // ALLOWED_ORIGINS in vitest.config.ts

async function json(res: Response) {
  return (await res.json()) as Record<string, any>
}

async function ticketFor(auth: { as?: TestActor; authorization?: string }) {
  const r = await call('/realtime/ticket', { method: 'POST', ...auth })
  expect(r.status).toBe(200)
  return (await json(r)).ticket as string
}

interface Live {
  ws: WebSocket
  events: () => Record<string, any>[]
  closeCode: () => number | null
}

async function connect(ticket: string): Promise<Live> {
  const res = await call(`/realtime/connect?ticket=${ticket}`, { headers: { Upgrade: 'websocket', Origin: ORIGIN } })
  expect(res.status).toBe(101)
  const ws = res.webSocket!
  const raw: string[] = []
  let code: number | null = null
  ws.addEventListener('message', (e) => raw.push(typeof e.data === 'string' ? e.data : ''))
  ws.addEventListener('close', (e) => {
    code = e.code
  })
  ws.accept()
  return { ws, events: () => raw.filter((m) => m.startsWith('{')).map((m) => JSON.parse(m)), closeCode: () => code }
}

const live = async (as: TestActor) => connect(await ticketFor({ as }))

async function until(check: () => boolean, ms = 3000) {
  const end = Date.now() + ms
  while (!check() && Date.now() < end) await new Promise((r) => setTimeout(r, 20))
  return check()
}

const about = (l: Live, id: string) => l.events().filter((e) => e.claimId === id || e.subjectId === id)

describe('connecting', () => {
  it('RT-01 tickets and API tokens are not interchangeable; Origin and upgrade are checked', async () => {
    expect((await call('/realtime/ticket', { method: 'POST' })).status).toBe(401)
    const ticket = await ticketFor({ as: customerA })
    // A ticket is not an API token.
    expect((await call('/claims', { authorization: `Bearer ${ticket}` })).status).toBe(401)
    // An API token is not a ticket.
    const apiToken = await mintToken(customerA)
    expect((await call(`/realtime/connect?ticket=${apiToken}`, { headers: { Upgrade: 'websocket', Origin: ORIGIN } })).status).toBe(401)
    // Cross-site WebSocket hijacking: another origin, or none, is refused.
    expect((await call(`/realtime/connect?ticket=${ticket}`, { headers: { Upgrade: 'websocket', Origin: 'https://evil.example' } })).status).toBe(403)
    expect((await call(`/realtime/connect?ticket=${ticket}`, { headers: { Upgrade: 'websocket' } })).status).toBe(403)
    expect((await call(`/realtime/connect?ticket=${ticket}`, { headers: { Origin: ORIGIN } })).status).toBe(426)
    expect((await call('/realtime/connect?ticket=garbage', { headers: { Upgrade: 'websocket', Origin: ORIGIN } })).status).toBe(401)
    const l = await connect(ticket)
    expect(await until(() => l.events().some((e) => e.type === 'hello'))).toBe(true)
    l.ws.close()
  })
})

describe('live consent round trip', () => {
  it('RT-10 the insurer sends, the customer opens and signs; each side sees it live, and nobody else does', async () => {
    const cust = await live(customerA)
    const staff = await live(assessorA)
    const otherCustomer = await live(customerB)
    const otherInsurer = await live(assessorB)
    const id = await createSubmittedClaim()
    expect(await until(() => about(staff, id).some((e) => e.type === 'claim.updated' && e.stage === 'Submitted'))).toBe(true)

    expect((await call(`/claims/${id}/verify`, { method: 'POST', as: assessorA })).status).toBe(200)
    expect(await until(() => about(cust, id).some((e) => e.type === 'consent.updated' && e.status === 'pending'))).toBe(true)
    expect(about(cust, id).some((e) => e.type === 'claim.updated' && e.stage === 'Verified')).toBe(true)

    // The customer opens the form → the insurer sees "viewed" (first open only).
    const list = await json(await call('/consents', { as: customerA }))
    const form = list.consents.find((x: { subjectId: string }) => x.subjectId === id)
    expect(form.viewedAt).toBeNull()
    expect((await json(await call(`/consents/${form.id}`, { as: customerA }))).consent.viewedAt).toEqual(expect.any(String))
    await call(`/consents/${form.id}`, { as: customerA })
    expect(await until(() => about(staff, id).some((e) => e.type === 'consent.updated' && e.status === 'viewed'))).toBe(true)
    expect(about(staff, id).filter((e) => e.status === 'viewed')).toHaveLength(1)

    await signClaimConsent(id)
    expect(await until(() => about(staff, id).some((e) => e.type === 'consent.updated' && e.status === 'signed'))).toBe(true)
    // The queue row carries the indicator.
    const row = (await json(await call('/claims?limit=50', { as: assessorA }))).claims.find((c: { id: string }) => c.id === id)
    expect(row).toMatchObject({ consent_status: 'signed', consent_viewed_at: expect.any(String) })

    // Isolation: another customer and another insurer heard nothing about this claim.
    await new Promise((r) => setTimeout(r, 100))
    expect(about(otherCustomer, id)).toHaveLength(0)
    expect(about(otherInsurer, id)).toHaveLength(0)
    // Notices carry ids, stages and statuses only (no names, amounts, reasons or text).
    const allowed = new Set(['type', 'at', 'claimId', 'stage', 'consentId', 'subjectType', 'subjectId', 'status', 'from', 'requestId', 'change', 'userId', 'applicationId', 'reason'])
    for (const e of [...cust.events(), ...staff.events()]) for (const k of Object.keys(e)) expect(allowed.has(k), k).toBe(true)
    for (const l of [cust, staff, otherCustomer, otherInsurer]) l.ws.close()
  })
})

describe('admin control, live', () => {
  it('RT-20 disabling an account signs its open app out at once; colleagues just see the team change', async () => {
    const created = await json(
      await call('/tenant/users', { method: 'POST', as: insurerAdminA, json: { username: 'rt_assessor', password: 'rt-pass-1234', displayName: 'RT', role: 'ASSESSOR' } })
    )
    const login = await json(await call('/auth/login', { method: 'POST', json: { username: 'rt_assessor', password: 'rt-pass-1234' } }))
    const spare = await ticketFor({ authorization: `Bearer ${login.token}` })
    const target = await connect(await ticketFor({ authorization: `Bearer ${login.token}` }))
    const colleague = await live(assessorA)

    expect((await call(`/tenant/users/${created.user.id}`, { method: 'PATCH', as: insurerAdminA, json: { status: 'disabled' } })).status).toBe(200)
    expect(await until(() => target.events().some((e) => e.type === 'session.revoked'))).toBe(true)
    expect(await until(() => target.closeCode() === 4001)).toBe(true)
    expect(await until(() => colleague.events().some((e) => e.type === 'team.updated' && e.userId === created.user.id))).toBe(true)
    expect(colleague.events().some((e) => e.type === 'session.revoked')).toBe(false)
    expect(colleague.closeCode()).toBeNull()
    // A ticket issued before the change no longer opens a connection.
    expect((await call(`/realtime/connect?ticket=${spare}`, { headers: { Upgrade: 'websocket', Origin: ORIGIN } })).status).toBe(401)
    colleague.ws.close()
  })

  it('RT-21 the insurer admin overview counts mandates by state', async () => {
    const id = await createSubmittedClaim()
    await call(`/claims/${id}/verify`, { method: 'POST', as: assessorA })
    const o = await json(await call('/tenant/overview', { as: insurerAdminA }))
    expect(o.attention).toMatchObject({
      awaitingMandate: expect.any(Number),
      mandateOpened: expect.any(Number),
      mandateDeclined: expect.any(Number),
      consentWithdrawn: expect.any(Number),
      infoNeeded: expect.any(Number),
      newClaims: expect.any(Number),
    })
    expect(o.attention.awaitingMandate).toBeGreaterThanOrEqual(1)
    // The admin's audit feed now includes customers' consent actions on this insurer's forms.
    const form = (await json(await call('/consents', { as: customerA }))).consents.find((x: { subjectId: string }) => x.subjectId === id)
    await call(`/consents/${form.id}`, { as: customerA })
    const feed = await json(await call('/tenant/audit?limit=50', { as: insurerAdminA }))
    expect(JSON.stringify(feed)).toContain('consent.viewed')
  })
})
