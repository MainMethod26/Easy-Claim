import type { Role } from '../types'

/**
 * Claim lifecycle. Stage values use the same title-case strings already stored in
 * seed_sa_data.sql and used by frontend/src/types (ClaimSummary.stage), so no data
 * migration is needed. `Draft` exists because POST /claims/initiate creates a draft
 * before the customer submits.
 *
 * Main path:  Draft → Submitted → Verified → Screening → Review → Decision → Paid
 * Side states: Info Needed, Appeal, Withdrawn, Expired
 */
export const CLAIM_STAGES = [
  'Draft',
  'Submitted',
  'Verified',
  'Screening',
  'Review',
  'Decision',
  'Paid',
  'Info Needed',
  'Appeal',
  'Withdrawn',
  'Expired',
] as const
export type ClaimStage = (typeof CLAIM_STAGES)[number]

export const MAIN_PATH: readonly ClaimStage[] = [
  'Submitted',
  'Verified',
  'Screening',
  'Review',
  'Decision',
  'Paid',
]

/** SYSTEM is for scheduled/automated jobs (e.g. expiry), never a request actor. */
export type TransitionActor = Role | 'SYSTEM'

const CUSTOMER: TransitionActor[] = ['CUSTOMER']
const INSURER: TransitionActor[] = ['ASSESSOR', 'MANAGER']
const MANAGER_ONLY: TransitionActor[] = ['MANAGER']
const SYSTEM: TransitionActor[] = ['SYSTEM']

/**
 * Allowed transitions and who may perform each. Anything absent is illegal.
 * ADMIN deliberately has no claim transitions (separation of duties: admins manage
 * configuration and users, not claim outcomes). Decision and payout are MANAGER-only
 * (Phase 3): assessors prepare a claim (verify, screen, review, request info) but do not
 * decide it or pay it.
 */
export const TRANSITIONS: Readonly<Record<ClaimStage, Partial<Record<ClaimStage, TransitionActor[]>>>> = {
  Draft: { Submitted: CUSTOMER, Withdrawn: CUSTOMER },
  Submitted: { Verified: INSURER, Withdrawn: CUSTOMER },
  Verified: { Screening: INSURER, Withdrawn: CUSTOMER },
  Screening: { Review: INSURER, 'Info Needed': INSURER, Withdrawn: CUSTOMER },
  Review: { Decision: MANAGER_ONLY, 'Info Needed': INSURER, Withdrawn: CUSTOMER },
  'Info Needed': { Screening: CUSTOMER, Withdrawn: CUSTOMER, Expired: SYSTEM },
  Decision: { Paid: MANAGER_ONLY, Appeal: CUSTOMER },
  Appeal: { Review: MANAGER_ONLY },
  Paid: {},
  Withdrawn: {},
  Expired: {},
}

export type TransitionResult =
  | { ok: true }
  | { ok: false; reason: 'unknown_stage' | 'illegal_transition' | 'role_not_permitted' }

export function isClaimStage(value: unknown): value is ClaimStage {
  return typeof value === 'string' && (CLAIM_STAGES as readonly string[]).includes(value)
}

export function checkTransition(from: unknown, to: unknown, actor: TransitionActor): TransitionResult {
  if (!isClaimStage(from) || !isClaimStage(to)) return { ok: false, reason: 'unknown_stage' }
  const allowed = TRANSITIONS[from][to]
  if (!allowed) return { ok: false, reason: 'illegal_transition' }
  if (!allowed.includes(actor)) return { ok: false, reason: 'role_not_permitted' }
  return { ok: true }
}
