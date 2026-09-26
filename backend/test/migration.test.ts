import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'

// The test database is created from the migrations and seeded with tenant_id already set,
// so the 0003 backfill (for local databases that pre-date tenants) is exercised here
// explicitly: seed rows are reset to the legacy shape and the migration's UPDATE
// statements are re-run.

describe('migration 0003 tenant backfill', () => {
  it('re-assigns the known seed policies by id, propagates to their claims, and leaves every other row NULL', async () => {
    await env.DB.batch([
      env.DB.prepare("UPDATE policies SET tenant_id = NULL WHERE id IN ('pol_disc_001', 'pol_mom_004')"),
      env.DB.prepare("UPDATE claims SET tenant_id = NULL WHERE id IN ('claim_disc_101', 'claim_mom_103')"),
      // legacy-shaped rows that merely look like a known insurer must NOT be re-homed
      env.DB.prepare("INSERT INTO policies (id, user_id, plan_name, status) VALUES ('legacy_disc', 'u1', 'Discovery Health Classic', 'Active')"),
      env.DB.prepare("INSERT INTO claims (id, user_id, policy_id, stage, status) VALUES ('legacy_claim_1', 'u1', 'legacy_disc', 'Submitted', 'Pending')"),
    ])

    const migration = env.TEST_MIGRATIONS.find((m) => m.name.startsWith('0003'))!
    const stripComments = (q: string) => q.replace(/^\s*--.*$/gm, '').trim()
    const backfill = migration.queries.map(stripComments).filter((q) => /^UPDATE /i.test(q))
    expect(backfill).toHaveLength(6) // 5 seed policies + claims-from-policy
    await env.DB.batch(backfill.map((q) => env.DB.prepare(q)))

    const policy = async (id: string) => (await env.DB.prepare('SELECT tenant_id FROM policies WHERE id = ?').bind(id).first<{ tenant_id: string | null }>())!.tenant_id
    const claim = async (id: string) => (await env.DB.prepare('SELECT tenant_id FROM claims WHERE id = ?').bind(id).first<{ tenant_id: string | null }>())!.tenant_id
    expect(await policy('pol_disc_001')).toBe('ins_discovery')
    expect(await policy('pol_mom_004')).toBe('ins_momentum')
    expect(await claim('claim_disc_101')).toBe('ins_discovery')
    expect(await claim('claim_mom_103')).toBe('ins_momentum')
    expect(await policy('legacy_disc')).toBeNull()
    expect(await claim('legacy_claim_1')).toBeNull() // stays invisible to every insurer (fail closed)
    // rows that already had a tenant are untouched
    expect(await policy('pol_sanlam_002')).toBe('ins_sanlam')
  })

  it('the backfill is idempotent', async () => {
    const migration = env.TEST_MIGRATIONS.find((m) => m.name.startsWith('0003'))!
    const backfill = migration.queries.map((q) => q.replace(/^\s*--.*$/gm, '').trim()).filter((q) => /^UPDATE /i.test(q))
    const before = await env.DB.prepare('SELECT id, tenant_id FROM policies ORDER BY id').all()
    await env.DB.batch(backfill.map((q) => env.DB.prepare(q)))
    const after = await env.DB.prepare('SELECT id, tenant_id FROM policies ORDER BY id').all()
    expect(after.results).toEqual(before.results)
  })

  it('tenant_id references the tenants table', async () => {
    await expect(
      env.DB.prepare("INSERT INTO policies (id, user_id, plan_name, status, tenant_id) VALUES ('bad', 'u', 'x', 'Active', 'ins_nope')").run()
    ).rejects.toThrow()
  })
})
