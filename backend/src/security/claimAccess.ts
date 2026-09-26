import type { Context } from 'hono'
import { INSURER_ROLES, type AppEnv } from '../types'
import { auditStatement, writeAuditEvent } from './audit'
import { checkTransition, type ClaimStage } from './claimStateMachine'

export interface ClaimRow {
  id: string
  user_id: string
  policy_id: string
  tenant_id: string | null
  stage: string
  status: string
  category: string | null
  cause_of_loss: string | null
  incident_date: string | null
  created_at: string | null
  updated_at: string | null
  // Phase 3 payout inputs (migrations/0005)
  claimed_amount_cents: number | null
  payout_bank_name: string | null
  payout_account_holder: string | null
  payout_account_last4: string | null
  payout_destination_hash: string | null
  payout_details_updated_at: string | null
}

/**
 * - 'read':        the owning CUSTOMER, or insurer staff of the claim's tenant
 * - 'owner-write': only the owning CUSTOMER
 * - 'insurer':     only insurer staff (ASSESSOR / MANAGER) of the claim's tenant
 */
export type ClaimAccessMode = 'read' | 'owner-write' | 'insurer'

type DenyReason = 'missing' | 'not_owner' | 'cross_tenant' | 'tenant_unset' | 'draft' | 'role' | 'mode'

/** Insurer staff may act on a claim only inside their own tenant, and only once it has been submitted. */
export function isTenantInsurer(actor: { role: string; tenantId: string | null }, claim: ClaimRow): boolean {
  return (
    INSURER_ROLES.includes(actor.role as never) &&
    actor.tenantId !== null &&
    claim.tenant_id !== null &&
    claim.tenant_id === actor.tenantId &&
    claim.stage !== 'Draft'
  )
}

/**
 * Object-level authorization for every route that takes a :claimId.
 *
 * Decision order: load → tenant boundary → ownership → mode. Returns null (caller responds
 * 404) both when the claim does not exist and when the actor may not access it, so claim
 * IDs cannot be probed for existence, across tenants or across customers.
 *
 * Fail-closed cases: a claim whose tenant_id is NULL is visible to no insurer; a Draft
 * (not yet submitted) is visible only to its owner.
 */
export async function loadAuthorizedClaim(
  c: Context<AppEnv>,
  claimId: string,
  mode: ClaimAccessMode
): Promise<ClaimRow | null> {
  const actor = c.get('actor')
  const claim = await c.env.DB.prepare('SELECT * FROM claims WHERE id = ?').bind(claimId).first<ClaimRow>()

  const isOwner = claim !== null && actor.role === 'CUSTOMER' && claim.user_id === actor.id
  const tenantInsurer = claim !== null && isTenantInsurer(actor, claim)

  const allowed = mode === 'owner-write' ? isOwner : mode === 'insurer' ? tenantInsurer : isOwner || tenantInsurer
  if (claim && allowed) return claim

  let reason: DenyReason
  if (!claim) reason = 'missing'
  else if (actor.role === 'CUSTOMER') reason = isOwner ? 'mode' : 'not_owner'
  else if (!INSURER_ROLES.includes(actor.role)) reason = 'role'
  else if (claim.tenant_id === null) reason = 'tenant_unset'
  else if (claim.tenant_id !== actor.tenantId) reason = 'cross_tenant'
  else if (claim.stage === 'Draft') reason = 'draft'
  else reason = 'mode'

  // Details name only the actor's own context, never the claim's tenant or owner.
  await writeAuditEvent(c, {
    action: 'authz.claim_access_denied',
    resourceType: 'claim',
    resourceId: claimId,
    outcome: 'denied',
    details: { mode, exists: claim !== null, reason },
  })
  return null
}

export type TransitionOutcome =
  | { ok: true }
  | { ok: false; status: 409; error: 'illegal_transition' | 'stale_state' }
  | { ok: false; status: 403; error: 'forbidden' }

export interface TransitionOptions {
  /** New claims.status written in the same statement as the stage change (e.g. decision outcome). */
  status?: string
  /** Extra identifiers/state names for the audit event. Never free text. */
  details?: Record<string, string | number | boolean | null>
  /**
   * Additional statements run in the SAME batch after the stage change and its audit row
   * (e.g. the decision or payout record). Each MUST be written as
   * `INSERT ... SELECT ... WHERE changes() = 1` so it is skipped when the stage change did
   * not apply (see gatedInsert in security/ledger.ts).
   */
  extra?: D1PreparedStatement[]
}

/**
 * The only code path that changes a claim's stage. Applies the state machine (including the
 * per-transition role), then runs ONE D1 batch (a transaction) containing the conditional
 * UPDATE on the stage the caller read and an audit INSERT gated on that UPDATE having
 * changed exactly one row. Concurrent or replayed requests therefore cannot apply twice,
 * and a stage change and its audit row always exist together.
 */
export async function transitionClaim(
  c: Context<AppEnv>,
  claim: ClaimRow,
  to: ClaimStage,
  opts: TransitionOptions = {}
): Promise<TransitionOutcome> {
  const actor = c.get('actor')

  // Defence in depth: callers must have loaded the claim through loadAuthorizedClaim, but the
  // transition re-asserts that this actor may touch this row (owner, or insurer of its tenant).
  const isOwner = actor.role === 'CUSTOMER' && claim.user_id === actor.id
  if (!isOwner && !isTenantInsurer(actor, claim)) {
    await writeAuditEvent(c, {
      action: 'authz.claim_access_denied',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { mode: 'transition', exists: true, reason: 'transition_guard' },
    })
    return { ok: false, status: 403, error: 'forbidden' }
  }

  const check = checkTransition(claim.stage, to, actor.role)

  if (!check.ok) {
    await writeAuditEvent(c, {
      action: 'claim.transition_rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { from: claim.stage, to, reason: check.reason, ...opts.details },
    })
    return check.reason === 'role_not_permitted'
      ? { ok: false, status: 403, error: 'forbidden' }
      : { ok: false, status: 409, error: 'illegal_transition' }
  }

  const now = new Date().toISOString()
  const update =
    opts.status === undefined
      ? c.env.DB.prepare('UPDATE claims SET stage = ?, updated_at = ? WHERE id = ? AND stage = ?').bind(to, now, claim.id, claim.stage)
      : c.env.DB.prepare('UPDATE claims SET stage = ?, status = ?, updated_at = ? WHERE id = ? AND stage = ?').bind(
          to,
          opts.status,
          now,
          claim.id,
          claim.stage
        )
  const audit = auditStatement(
    c,
    {
      action: 'claim.stage_changed',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'success',
      details: { from: claim.stage, to, ...opts.details },
    },
    { onlyIfPreviousChanged: true }
  )

  const [updated] = await c.env.DB.batch([update, audit, ...(opts.extra ?? [])])
  if (updated.meta.changes !== 1) {
    // The row moved on between the read and the write (lost race / replay). Record the attempt.
    await writeAuditEvent(c, {
      action: 'claim.transition_rejected',
      resourceType: 'claim',
      resourceId: claim.id,
      outcome: 'denied',
      details: { from: claim.stage, to, reason: 'stale_state', ...opts.details },
    })
    return { ok: false, status: 409, error: 'stale_state' }
  }
  return { ok: true }
}
