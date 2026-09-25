import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { call, createReadyDraft, customerA } from './helpers'

describe('security audit trail', () => {
  it('audit rows cannot be updated or deleted', async () => {
    await createReadyDraft()
    await expect(env.DB.prepare("UPDATE audit_events SET outcome = 'success'").run()).rejects.toThrow(/append-only/)
    await expect(env.DB.prepare('DELETE FROM audit_events').run()).rejects.toThrow(/append-only/)
  })

  it('audit rows do not contain free-text claim narratives or headers', async () => {
    const claimId = await createReadyDraft()
    await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
    const { results } = await env.DB.prepare('SELECT * FROM audit_events').all()
    const dump = JSON.stringify(results)
    expect(dump).not.toContain('Hospital admission') // causeOfLoss text
    expect(dump).not.toContain('X-Dev-Actor')
  })

  it('every audit row records actor, action, outcome and request id', async () => {
    await createReadyDraft()
    const { results } = await env.DB.prepare('SELECT * FROM audit_events').all<Record<string, unknown>>()
    expect(results.length).toBeGreaterThan(0)
    for (const row of results) {
      expect(row.actor_id).toBeTruthy()
      expect(row.action).toBeTruthy()
      expect(row.outcome).toBeTruthy()
      expect(row.request_id).toBeTruthy()
    }
  })
})
