import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import {
  admin,
  assessorA,
  assessorB,
  auditRows,
  call,
  claimStage,
  createSubmittedClaim,
  customerA,
  managerA,
  managerB,
} from './helpers'

// Seed: claim_disc_101 (tenant A = ins_discovery, Review), claim_sanlam_102 (tenant B =
// ins_sanlam, Decision/Approved), claim_mom_103 (ins_momentum, Submitted).

describe('tenant isolation', () => {
  it('TENANT-001 tenant B assessor cannot read a tenant A claim (404, audited as cross_tenant)', async () => {
    const res = await call('/claims/claim_disc_101/timeline', { as: assessorB })
    expect(res.status).toBe(404)
    expect(await res.text()).not.toContain('user123')
    const rows = await auditRows('authz.claim_access_denied', 'claim_disc_101')
    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({ actor_id: 'assessor_b1', actor_role: 'ASSESSOR', actor_tenant_id: 'ins_sanlam', outcome: 'denied' })
    expect(JSON.parse(rows[0].details as string)).toMatchObject({ reason: 'cross_tenant', exists: true })
    // the denial row names the actor's context only, never the target claim's tenant or owner
    const row = JSON.stringify(rows[0])
    expect(row).not.toContain('ins_discovery')
    expect(row).not.toContain('user123')
  })

  it('TENANT-001b an ADMIN token carrying a tenant still gets no claim or list access', async () => {
    const adminA = { id: 'admin_a', role: 'ADMIN', tenantId: 'ins_discovery' }
    expect((await call('/claims/claim_disc_101/timeline', { as: adminA })).status).toBe(404)
    expect((await call('/claims', { as: adminA })).status).toBe(403)
    expect((await call('/claims/claim_disc_101/verify', { method: 'POST', as: adminA })).status).toBe(403)
  })

  it('TENANT-001c unsubmitted drafts are invisible to insurer staff of the same tenant', async () => {
    const res = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } })
    const { claimId } = (await res.json()) as { claimId: string }
    expect((await call(`/claims/${claimId}/timeline`, { as: assessorA })).status).toBe(404)
    expect((await call(`/claims/${claimId}/verify`, { method: 'POST', as: assessorA })).status).toBe(404)
    const list = (await (await call('/claims', { as: assessorA })).json()) as { claims: { id: string }[] }
    expect(list.claims.map((c) => c.id)).not.toContain(claimId)
    const rows = await auditRows('authz.claim_access_denied', claimId)
    expect(JSON.parse(rows[0].details as string)).toMatchObject({ reason: 'draft' })
  })

  it('TENANT-002 tenant A staff cannot transition a tenant C claim through any insurer route; stage unchanged', async () => {
    for (const step of ['verify', 'screen', 'review', 'request-info', 'pay']) {
      expect((await call(`/claims/claim_mom_103/${step}`, { method: 'POST', as: assessorA })).status).toBe(404)
      expect((await call(`/claims/claim_mom_103/${step}`, { method: 'POST', as: managerA })).status).toBe(404)
    }
    expect((await call('/claims/claim_mom_103/decide', { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'test' } })).status).toBe(404)
    expect(await claimStage('claim_mom_103')).toMatchObject({ stage: 'Submitted', status: 'Pending' })
    expect(await auditRows('claim.stage_changed', 'claim_mom_103')).toHaveLength(0)
    const denials = await auditRows('authz.claim_access_denied', 'claim_mom_103')
    expect(denials).toHaveLength(11)
    expect(denials.every((r) => JSON.parse(r.details as string).reason === 'cross_tenant')).toBe(true)
  })

  it('TENANT-002b tenant B manager cannot decide or pay a tenant A claim', async () => {
    expect((await call('/claims/claim_disc_101/decide', { method: 'POST', as: managerB, json: { outcome: 'Approved', reason: 'test' } })).status).toBe(404)
    expect((await call('/claims/claim_disc_101/pay', { method: 'POST', as: managerB })).status).toBe(404)
    expect(await claimStage('claim_disc_101')).toMatchObject({ stage: 'Review', status: 'Processing' })
  })

  it('TENANT-003 tenant B assessor cannot read a tenant A decision', async () => {
    expect((await call('/claims/claim_disc_101/decision', { as: assessorB })).status).toBe(404)
  })

  it('TENANT-003b cross-tenant and non-existent claims are indistinguishable', async () => {
    const cross = await call('/claims/claim_disc_101/timeline', { as: assessorB })
    const missing = await call('/claims/claim_nope/timeline', { as: assessorB })
    expect(cross.status).toBe(missing.status)
    expect(await cross.json()).toEqual(await missing.json())
  })

  it('TENANT-004 evidence resource isolation: tenant B staff cannot list a tenant A claim\'s evidence (404)', async () => {
    // Phase 2 added the evidence routes; full upload/download/verify isolation is in test/evidence.test.ts.
    expect((await call('/claims/claim_disc_101/evidence', { as: assessorB })).status).toBe(404)
    expect((await call('/claims/claim_disc_101/evidence', { as: assessorA })).status).toBe(200)
  })

  it('TENANT-005 a claim with no tenant is visible to no insurer (fail closed)', async () => {
    await env.DB.prepare(
      "INSERT INTO claims (id, user_id, policy_id, stage, status) VALUES ('claim_orphan', 'user123', 'pol_disc_001', 'Submitted', 'Pending')"
    ).run()
    expect((await call('/claims/claim_orphan/timeline', { as: assessorA })).status).toBe(404)
    expect((await call('/claims/claim_orphan/verify', { method: 'POST', as: assessorA })).status).toBe(404)
    const rows = await auditRows('authz.claim_access_denied', 'claim_orphan')
    expect(JSON.parse(rows[0].details as string)).toMatchObject({ reason: 'tenant_unset' })
    // the owner can still see it
    expect((await call('/claims/claim_orphan/timeline', { as: customerA })).status).toBe(200)
  })

  it('TENANT-006 list endpoint is scoped per tenant / per owner', async () => {
    const idsWhere = async (sql: string, v: string) =>
      (await env.DB.prepare(`SELECT id FROM claims WHERE ${sql} ORDER BY id`).bind(v).all<{ id: string }>()).results.map((r) => r.id)

    const a = (await (await call('/claims', { as: assessorA })).json()) as { claims: { id: string; tenant_id: string }[] }
    expect(a.claims.map((c) => c.id).sort()).toEqual(await idsWhere("tenant_id = ? AND stage <> 'Draft'", 'ins_discovery'))
    expect(a.claims).toContainEqual(expect.objectContaining({ id: 'claim_disc_101' }))
    expect(a.claims.every((c) => c.tenant_id === 'ins_discovery')).toBe(true)
    // platform-wide customer ids are not exposed to tenant staff
    expect(JSON.stringify(a.claims)).not.toContain('user_id')
    expect(JSON.stringify(a.claims)).not.toContain('user123')

    const b = (await (await call('/claims', { as: assessorB })).json()) as { claims: { id: string; tenant_id: string }[] }
    expect(b.claims.map((c) => c.id).sort()).toEqual(await idsWhere("tenant_id = ? AND stage <> 'Draft'", 'ins_sanlam'))
    expect(b.claims.map((c) => c.id)).not.toContain('claim_disc_101')

    const mine = (await (await call('/claims', { as: customerA })).json()) as { claims: { id: string }[] }
    expect(mine.claims.map((c) => c.id).sort()).toEqual(await idsWhere('user_id = ?', 'user123'))
    expect(JSON.stringify(mine.claims)).not.toContain('user_id')
    expect((await call('/claims', { as: admin })).status).toBe(403)
    expect((await call('/claims?limit=500', { as: assessorA })).status).toBe(400)
  })

  it('TENANT-007 initiate copies tenant from the policy; a policy without tenant is not eligible', async () => {
    const claimId = await createSubmittedClaim()
    expect(await claimStage(claimId)).toMatchObject({ tenant_id: 'ins_discovery' })
    await env.DB.prepare(
      "INSERT INTO policies (id, user_id, plan_name, status) VALUES ('pol_no_tenant', 'user123', 'Unknown Insurer Plan', 'Active')"
    ).run()
    const res = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_no_tenant' } })
    expect(res.status).toBe(422)
    const rows = await auditRows('claim.initiate_rejected', 'pol_no_tenant')
    expect(JSON.parse(rows[0].details as string)).toMatchObject({ reason: 'policy_missing_tenant' })
  })
})

describe('insurer transitions (role + tenant + state machine)', () => {
  it('STATE-001 valid role + tenant: full path Submitted → … → Paid, each step audited', async () => {
    const id = await createSubmittedClaim()

    expect((await call(`/claims/${id}/verify`, { method: 'POST', as: assessorA })).status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Verified' })
    expect((await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })).status).toBe(200)
    expect((await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })).status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Review' })

    const decide = await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'test' } })
    expect(decide.status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Decision', status: 'Approved' })
    expect(await (await call(`/claims/${id}/decision`, { as: customerA })).json()).toMatchObject({ decision: 'Approved' })

    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Paid' })

    const changes = await auditRows('claim.stage_changed', id)
    expect(changes.map((r) => JSON.parse(r.details as string).to)).toEqual([
      'Submitted',
      'Verified',
      'Screening',
      'Review',
      'Decision',
      'Paid',
    ])
    expect(changes.every((r) => r.request_id)).toBe(true)
    const timeline = (await (await call(`/claims/${id}/timeline`, { as: customerA })).json()) as { timeline: { completed: boolean; date: string | null }[] }
    expect(timeline.timeline.every((t) => t.completed && t.date !== null)).toBe(true)
  })

  it('STATE-002 correct role, wrong tenant → 404 and no change', async () => {
    const id = await createSubmittedClaim()
    expect((await call(`/claims/${id}/verify`, { method: 'POST', as: assessorB })).status).toBe(404)
    expect(await claimStage(id)).toMatchObject({ stage: 'Submitted' })
  })

  it('STATE-003 correct tenant, insufficient role → 403 (assessor cannot pay), audited', async () => {
    const id = await createSubmittedClaim()
    for (const step of ['verify', 'screen', 'review']) await call(`/claims/${id}/${step}`, { method: 'POST', as: assessorA })
    await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'test' } })

    const res = await call(`/claims/${id}/pay`, { method: 'POST', as: assessorA })
    expect(res.status).toBe(403)
    expect(await claimStage(id)).toMatchObject({ stage: 'Decision' })
    const rejected = await auditRows('claim.transition_rejected', id)
    expect(JSON.parse(rejected[0].details as string)).toMatchObject({ to: 'Paid', reason: 'role_not_permitted' })
  })

  it('STATE-004 illegal transitions are rejected with 409 (skip verification, pay before decision)', async () => {
    const id = await createSubmittedClaim()
    expect((await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })).status).toBe(409) // Submitted → Screening
    expect((await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })).status).toBe(409)
    expect((await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'test' } })).status).toBe(409)
    expect((await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).status).toBe(409)
    expect(await claimStage(id)).toMatchObject({ stage: 'Submitted' })
  })

  it('STATE-005 a rejected decision cannot be paid, but can be appealed and re-reviewed by a manager', async () => {
    const id = await createSubmittedClaim()
    for (const step of ['verify', 'screen', 'review']) await call(`/claims/${id}/${step}`, { method: 'POST', as: assessorA })
    await call(`/claims/${id}/decide`, { method: 'POST', as: managerA, json: { outcome: 'Rejected', reason: 'test' } })

    expect(await (await call(`/claims/${id}/pay`, { method: 'POST', as: managerA })).json()).toEqual({ error: 'not_approved' })
    expect((await call(`/claims/${id}/appeal`, { method: 'POST', as: customerA, json: { reason: 'New evidence' } })).status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Appeal' })
    expect((await call(`/claims/${id}/review`, { method: 'POST', as: assessorA })).status).toBe(403) // Appeal → Review is MANAGER-only
    expect((await call(`/claims/${id}/review`, { method: 'POST', as: managerA })).status).toBe(200)
  })

  it('STATE-006 request-info round trip: insurer asks, customer answers, claim returns to Screening', async () => {
    const id = await createSubmittedClaim()
    await call(`/claims/${id}/verify`, { method: 'POST', as: assessorA })
    await call(`/claims/${id}/screen`, { method: 'POST', as: assessorA })
    expect((await call(`/claims/${id}/request-info`, { method: 'POST', as: assessorA })).status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Info Needed' })
    const answer = await call(`/claims/${id}/screening`, {
      method: 'PATCH',
      as: customerA,
      json: { causeOfLoss: 'Additional detail', incidentDate: '2026-01-10' },
    })
    expect(answer.status).toBe(200)
    expect(await claimStage(id)).toMatchObject({ stage: 'Screening' })
  })

  it('RBAC-001 customers cannot call insurer transitions (403, no claim data, claim never loaded)', async () => {
    const objectDenialsBefore = (await auditRows('authz.claim_access_denied', 'claim_disc_101')).length
    const roleDenialsBefore = (await auditRows('authz.role_denied')).length
    for (const step of ['verify', 'screen', 'review', 'request-info', 'pay']) {
      const res = await call(`/claims/claim_disc_101/${step}`, { method: 'POST', as: customerA })
      expect(res.status).toBe(403)
      expect(await res.json()).toEqual({ error: 'forbidden' })
    }
    const decide = await call('/claims/claim_disc_101/decide', { method: 'POST', as: customerA, json: { outcome: 'Approved', reason: 'test' } })
    expect(decide.status).toBe(403)
    expect(await decide.json()).toEqual({ error: 'forbidden' })
    expect(await claimStage('claim_disc_101')).toMatchObject({ stage: 'Review', status: 'Processing' })
    // the coarse role gate ran before any claim lookup: six new role denials, no new object-level denial rows
    expect((await auditRows('authz.claim_access_denied', 'claim_disc_101')).length).toBe(objectDenialsBefore)
    expect((await auditRows('authz.role_denied')).length).toBe(roleDenialsBefore + 6)
  })

  it('RBAC-002 admin cannot transition claims', async () => {
    expect((await call('/claims/claim_disc_101/decide', { method: 'POST', as: admin, json: { outcome: 'Approved', reason: 'test' } })).status).toBe(403)
  })

  it('decide rejects invalid or extra fields (mass assignment)', async () => {
    expect((await call('/claims/claim_disc_101/decide', { method: 'POST', as: managerA, json: { outcome: 'Paid', reason: 'test' } })).status).toBe(400)
    expect((await call('/claims/claim_disc_101/decide', { method: 'POST', as: managerA, json: { outcome: 'Approved', reason: 'test', amount: 1000000 } })).status).toBe(400)
    expect(await claimStage('claim_disc_101')).toMatchObject({ stage: 'Review' })
  })

  it('AUDIT-001 cross-tenant and role denials are recorded with the acting tenant / actor id', async () => {
    await call('/claims/claim_disc_101/verify', { method: 'POST', as: assessorB })
    await call('/claims/claim_disc_101/pay', { method: 'POST', as: customerA })
    const denied = await env.DB.prepare("SELECT * FROM audit_events WHERE outcome = 'denied'").all<Record<string, unknown>>()
    expect(denied.results.length).toBeGreaterThanOrEqual(2)
    expect(denied.results.some((r) => r.action === 'authz.claim_access_denied' && r.actor_tenant_id === 'ins_sanlam')).toBe(true)
    expect(denied.results.some((r) => r.action === 'authz.role_denied' && r.actor_id === 'user123')).toBe(true)
  })
})
