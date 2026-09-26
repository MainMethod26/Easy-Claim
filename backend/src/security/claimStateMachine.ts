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
const INSURER: TransitionActor[] = ['INSURER_ADMIN']
const SYSTEM: TransitionActor[] = ['SYSTEM']

/**
 * Allowed transitions and who may perform each. Anything absent is illegal.
 * SUPERADMIN deliberately has no claim transitions (platform operator, never a claim
 * outcome). The insurer side is one role, INSURER_ADMIN (team decision, 26 Sep 2026): it
 * verifies, screens, reviews, decides and pays. KNOWN LIMITATION: the assessor/manager
 * separation of duties from Phase 3 no longer exists; see docs/SECURITY_INTEGRATION.md.
 */
export const TRANSITIONS: Readonly<Record<ClaimStage, Partial<Record<ClaimStage, TransitionActor[]>>>> = {
  Draft: { Submitted: CUSTOMER, Withdrawn: CUSTOMER },
  Submitted: { Verified: INSURER, Withdrawn: CUSTOMER },
  Verified: { Screening: INSURER, Withdrawn: CUSTOMER },
  Screening: { Review: INSURER, 'Info Needed': INSURER, Withdrawn: CUSTOMER },
  Review: { Decision: INSURER, 'Info Needed': INSURER, Withdrawn: CUSTOMER },
  'Info Needed': { Screening: CUSTOMER, Withdrawn: CUSTOMER, Expired: SYSTEM },
  Decision: { Paid: INSURER, Appeal: CUSTOMER },
  Appeal: { Review: INSURER },
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
