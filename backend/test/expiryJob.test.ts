import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { EXPIRY_DAYS, expireStaleInfoNeeded } from '../src/jobs/expireInfoNeeded'
import { auditRows, claimStage } from './helpers'

// Nightly job (wrangler.toml [triggers]): Info Needed -> Expired after EXPIRY_DAYS, through the
// state machine's SYSTEM edge, conditional on the stage and audited in the same batch.

const NOW = new Date('2026-09-26T00:00:00Z')
const daysAgo = (n: number) => new Date(NOW.getTime() - n * 24 * 3600 * 1000).toISOString()

async function insertClaim(id: string, stage: string, updatedAt: string) {
  await env.DB.prepare(
    `INSERT INTO claims (id, user_id, policy_id, stage, status, tenant_id, created_at, updated_at)
     VALUES (?, 'user123', 'pol_disc_001', ?, 'Pending', 'ins_discovery', ?, ?)`
  )
    .bind(id, stage, updatedAt, updatedAt)
    .run()
}

describe('expiry job', () => {
  it(`expires Info Needed claims older than ${EXPIRY_DAYS} days, audited as SYSTEM; leaves newer and other-stage claims alone; idempotent`, async () => {
    await insertClaim('claim_exp_old', 'Info Needed', daysAgo(31))
    await insertClaim('claim_exp_new', 'Info Needed', daysAgo(29))
    await insertClaim('claim_exp_review', 'Review', daysAgo(90))

    expect(await expireStaleInfoNeeded(env as never, NOW)).toBe(1)

    expect(await claimStage('claim_exp_old')).toMatchObject({ stage: 'Expired', status: 'Closed' })
    expect(await claimStage('claim_exp_new')).toMatchObject({ stage: 'Info Needed', status: 'Pending' })
    expect(await claimStage('claim_exp_review')).toMatchObject({ stage: 'Review' })

    const rows = await auditRows('claim.stage_changed', 'claim_exp_old')
    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({ actor_role: 'SYSTEM', outcome: 'success', resource_type: 'claim' })
    expect(JSON.parse(rows[0].details as string)).toMatchObject({ from: 'Info Needed', to: 'Expired' })
    expect(await auditRows('claim.stage_changed', 'claim_exp_new')).toHaveLength(0)
    expect(await auditRows('claim.stage_changed', 'claim_exp_review')).toHaveLength(0)

    // Running again changes nothing and writes no further audit row.
    expect(await expireStaleInfoNeeded(env as never, NOW)).toBe(0)
    expect(await auditRows('claim.stage_changed', 'claim_exp_old')).toHaveLength(1)
  })

  it('a claim the customer answers in the same batch window is not expired (conditional update, no audit row)', async () => {
    await insertClaim('claim_exp_race', 'Info Needed', daysAgo(40))
    // The customer answers first: the claim goes back to Screening before the job's UPDATE runs.
    await env.DB.prepare("UPDATE claims SET stage = 'Screening' WHERE id = 'claim_exp_race'").run()
    expect(await expireStaleInfoNeeded(env as never, NOW)).toBe(0)
    expect(await claimStage('claim_exp_race')).toMatchObject({ stage: 'Screening' })
    expect(await auditRows('claim.stage_changed', 'claim_exp_race')).toHaveLength(0)
  })
})
