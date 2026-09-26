import type { Bindings } from '../types'
import { checkTransition } from '../security/claimStateMachine'

/**
 * Nightly job (wrangler.toml [triggers] crons): a claim left in 'Info Needed' for more than
 * EXPIRY_DAYS without the customer answering moves to 'Expired'.
 *
 * Same guarantees as every request-driven transition (security/claimAccess.ts transitionClaim):
 * - the edge must exist in the state machine for the SYSTEM actor (Info Needed -> Expired);
 * - the UPDATE is conditional on the claim still being in 'Info Needed' (no race with a customer
 *   answering at the same moment);
 * - the audit row is written in the same D1 batch and only if that UPDATE changed a row.
 */
export const EXPIRY_DAYS = 30

export async function expireStaleInfoNeeded(env: Bindings, now: Date = new Date()): Promise<number> {
  if (!checkTransition('Info Needed', 'Expired', 'SYSTEM').ok) return 0
  const cutoff = new Date(now.getTime() - EXPIRY_DAYS * 24 * 3600 * 1000).toISOString()
  const { results } = await env.DB.prepare(
    `SELECT id, tenant_id FROM claims WHERE stage = 'Info Needed' AND updated_at < ?`
  )
    .bind(cutoff)
    .all<{ id: string; tenant_id: string | null }>()

  const at = now.toISOString()
  const statements: D1PreparedStatement[] = []
  for (const claim of results) {
    statements.push(
      env.DB.prepare(
        `UPDATE claims SET stage = 'Expired', status = 'Closed', updated_at = ? WHERE id = ? AND stage = 'Info Needed'`
      ).bind(at, claim.id),
      env.DB.prepare(
        `INSERT INTO audit_events (id, occurred_at, actor_id, actor_role, actor_tenant_id, action, resource_type, resource_id, outcome, request_id, details)
         SELECT ?, ?, 'system', 'SYSTEM', NULL, 'claim.stage_changed', 'claim', ?, 'success', NULL, ? WHERE changes() = 1`
      ).bind(crypto.randomUUID(), at, claim.id, JSON.stringify({ from: 'Info Needed', to: 'Expired', reason: `no customer response for ${EXPIRY_DAYS} days` }))
    )
  }
  if (statements.length) await env.DB.batch(statements)
  return results.length
}
