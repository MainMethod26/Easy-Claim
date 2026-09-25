import type { Context } from 'hono'
import { INSURER_ROLES, type AppEnv } from '../types'
import { writeAuditEvent } from './audit'
import { checkTransition, type ClaimStage } from './claimStateMachine'

export interface ClaimRow {
  id: string
  user_id: string
  policy_id: string
  stage: string
  status: string
  category: string | null
  cause_of_loss: string | null
  incident_date: string | null
  created_at: string | null
  updated_at: string | null
}

export type ClaimAccessMode = 'read' | 'owner-write'

/**
 * Object-level authorization for every route that takes a :claimId.
 *
 * - 'read': the owning CUSTOMER, or an insurer role (ASSESSOR/MANAGER).
 * - 'owner-write': only the owning CUSTOMER.
 *
 * Returns null (caller responds 404) both when the claim does not exist and when the
 * actor may not access it, so claim IDs cannot be probed for existence.
 */
export async function loadAuthorizedClaim(
  c: Context<AppEnv>,
  claimId: string,
  mode: ClaimAccessMode
): Promise<ClaimRow | null> {
  const actor = c.get('actor')
  const claim = await c.env.DB.prepare('SELECT * FROM claims WHERE id = ?').bind(claimId).first<ClaimRow>()

  const isOwner = claim !== null && actor.role === 'CUSTOMER' && claim.user_id === actor.id
  const isInsurer = INSURER_ROLES.includes(actor.role)
  const allowed = mode === 'owner-write' ? isOwner : isOwner || isInsurer

  if (claim && allowed) return claim

  await writeAuditEvent(c, {
    action: 'authz.claim_access_denied',
    resourceType: 'claim',
    resourceId: claimId,
    outcome: 'denied',
    details: { mode, exists: claim !== null },
  })
  return null
}

export type TransitionOutcome =
  | { ok: true }
  | { ok: false; status: 409; error: 'illegal_transition' | 'stale_state' }
  | { ok: false; status: 403; error: 'forbidden' }

/**
 * Applies a stage change through the state machine. The UPDATE is conditional on the
 * stage the caller read, so concurrent/replayed requests cannot apply twice.
 */
export async function transitionClaim(
  c: Context<AppEnv>,
  claim: ClaimRow,
  to: ClaimStage
): Promise<TransitionOutcome> {
  const actor = c.get('actor')
  const check = checkTransition(claim.stage, to, actor.role)

  if (!check.ok) {
    await writeAuditEvent(c, {
      action: 'claim.transition_rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { from: claim.stage, to, reason: check.reason },
    })
    return check.reason === 'role_not_permitted'
      ? { ok: false, status: 403, error: 'forbidden' }
      : { ok: false, status: 409, error: 'illegal_transition' }
  }

  const result = await c.env.DB.prepare(
    'UPDATE claims SET stage = ?, updated_at = ? WHERE id = ? AND stage = ?'
  )
    .bind(to, new Date().toISOString(), claim.id, claim.stage)
    .run()

  if (result.meta.changes !== 1) return { ok: false, status: 409, error: 'stale_state' }

  await writeAuditEvent(c, {
    action: 'claim.stage_changed',
    resourceType: 'claim',
    resourceId: claim.id,
    outcome: 'success',
    details: { from: claim.stage, to },
  })
  return { ok: true }
}
