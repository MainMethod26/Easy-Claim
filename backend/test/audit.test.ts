import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { auditRows, call, createReadyDraft, customerA } from './helpers'

describe('security audit trail', () => {
  it('audit rows cannot be updated or deleted', async () => {
    await createReadyDraft()
    await expect(env.DB.prepare("UPDATE audit_events SET outcome = 'success'").run()).rejects.toThrow(/append-only/)
    await expect(env.DB.prepare('DELETE FROM audit_events').run()).rejects.toThrow(/append-only/)
  })

  it('audit rows do not contain free-text claim narratives, headers or tokens', async () => {
    const claimId = await createReadyDraft()
    await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
    const { results } = await env.DB.prepare('SELECT * FROM audit_events').all()
    const dump = JSON.stringify(results)
    expect(dump).not.toContain('Hospital admission') // causeOfLoss text
    expect(dump).not.toContain('X-Dev-Actor')
    expect(dump).not.toContain('Bearer')
    expect(dump).not.toContain('eyJ')
  })

  it('a stage-change audit row is written only when the stage change applied (same transaction)', async () => {
    const claimId = await createReadyDraft()
    // Simulate the batch transitionClaim runs, with a stale precondition: 0 rows change.
    const stale = env.DB.prepare("UPDATE claims SET stage = 'Submitted' WHERE id = ? AND stage = 'Review'").bind(claimId)
    const gated = env.DB.prepare(
      `INSERT INTO audit_events (id, occurred_at, actor_id, actor_role, actor_tenant_id, action, resource_type, resource_id, outcome, request_id, details)
       SELECT 'probe-1', '2026-01-01T00:00:00Z', 'user123', 'CUSTOMER', NULL, 'claim.stage_changed', 'claim', ?, 'success', 'r', '{"to":"Submitted"}'
       WHERE changes() = 1`
    ).bind(claimId)
    const [staleResult] = await env.DB.batch([stale, gated])
    expect(staleResult.meta.changes).toBe(0)
    expect(await auditRows('claim.stage_changed', claimId)).toHaveLength(0)

    // Same batch with a matching precondition: both the update and the audit row land.
    const fresh = env.DB.prepare("UPDATE claims SET stage = 'Submitted' WHERE id = ? AND stage = 'Draft'").bind(claimId)
    const [freshResult] = await env.DB.batch([fresh, gated])
    expect(freshResult.meta.changes).toBe(1)
    expect(await auditRows('claim.stage_changed', claimId)).toHaveLength(1)
  })

  it('concurrent submits of the same claim: exactly one applies, one is rejected, one stage_changed row (real transitionClaim path)', async () => {
    const claimId = await createReadyDraft()
    const [a, b] = await Promise.all([
      call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA }),
      call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA }),
    ])
    expect([a.status, b.status].sort()).toEqual([200, 409])
    const loser = a.status === 409 ? a : b
    expect(['stale_state', 'illegal_transition']).toContain(((await loser.json()) as { error: string }).error)
    expect(await auditRows('claim.stage_changed', claimId)).toHaveLength(1)
    expect(await auditRows('claim.transition_rejected', claimId)).toHaveLength(1)
    expect(await env.DB.prepare('SELECT stage FROM claims WHERE id = ?').bind(claimId).first()).toEqual({ stage: 'Submitted' })
  })

  it('request ids in audit rows are server-generated, never taken from the client', async () => {
    const claimId = await createReadyDraft()
    await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA, headers: { 'X-Request-Id': 'attacker-chosen-id' } })
    const rows = await auditRows('claim.stage_changed', claimId)
    expect(rows[0].request_id).toMatch(/^[0-9a-f-]{36}$/)
    expect(rows[0].request_id).not.toBe('attacker-chosen-id')
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
