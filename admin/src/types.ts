/**
 * Types for the admin app. Every shape here mirrors what the backend Worker actually returns
 * (see docs/API_CONTRACT.md and backend/src/endpoints/*). Nothing is filled in on the client:
 * a value the backend did not send is `null`, and the UI shows "—" / "Not provided".
 */

export type Role = 'CUSTOMER' | 'ASSESSOR' | 'MANAGER' | 'INSURER_ADMIN' | 'SUPERADMIN'

export const ROLES: readonly Role[] = ['CUSTOMER', 'ASSESSOR', 'MANAGER', 'INSURER_ADMIN', 'SUPERADMIN']

export type ClaimStage =
  | 'Draft'
  | 'Submitted'
  | 'Verified'
  | 'Screening'
  | 'Review'
  | 'Decision'
  | 'Paid'
  | 'Info Needed'
  | 'Appeal'
  | 'Withdrawn'
  | 'Expired'

export const CLAIM_STAGES: readonly ClaimStage[] = [
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
]

/** The signed-in account, exactly as returned by POST /auth/login (`actor`). */
export interface Actor {
  id: string
  username: string
  role: Role
  tenantId: string | null
  displayName: string | null
  status: string | null
}

/** What is kept for a session: the token and actor from the backend, plus the expiry it stated. */
export interface Session {
  token: string
  /** Epoch ms; derived from the backend's `expiresIn` (seconds). null when not stated. */
  expiresAt: number | null
  actor: Actor
}

/** One row of GET /claims (backend sends snake_case; no payout fields, no incident date). */
export interface ClaimSummary {
  id: string
  policyId: string
  tenantId: string | null
  stage: string
  status: string | null
  category: string | null
  claimedAmountCents: number | null
  createdAt: string | null
  updatedAt: string | null
}

export interface MessageRef {
  body: string
  createdAt: string | null
}

/** GET /claims/:id → claim */
export interface ClaimDetail {
  id: string
  policyId: string
  planName: string | null
  tenantId: string | null
  insurerName: string | null
  stage: string
  status: string | null
  category: string | null
  causeOfLoss: string | null
  incidentDate: string | null
  claimedAmountCents: number | null
  payoutDestination: { bankName: string | null; accountLast4: string } | null
  createdAt: string | null
  updatedAt: string | null
  infoRequest: MessageRef | null
  appealReason: MessageRef | null
}

/** GET /claims/:id/timeline → timeline[] */
export interface TimelineEntry {
  stage: string
  completed: boolean
  date: string | null
}

export interface Timeline {
  currentStage: string | null
  entries: TimelineEntry[]
}

export type AnomalyBand = 'NORMAL' | 'ELEVATED' | 'HIGH'

/** GET /claims/:id/risk-signals → riskSignals (ASSESSOR/MANAGER only; null when none computed). */
export interface RiskSignals {
  classicalAnomaly: number
  quantumAnomaly: number
  interpretation: string
  anomalyBand: AnomalyBand
  screeningRecommendation: 'STANDARD_REVIEW' | 'REVIEW_REQUIRED'
  explanation: string
  versions: { model: string | null; features: string | null; kernel: string | null; screening: string | null } | null
  signalDigest: string | null
  modelVersion: string
  execution: 'simulator' | 'hardware'
  computedAt: string | null
  advisory: boolean
}

/** GET /claims/:id/decision */
export interface DecisionInfo {
  decision: string
  record: {
    id: string
    decidedAt: string | null
    decidedByRole: string | null
    reason: string | null
    approvedAmountCents: number | null
    rulesVersion: string | null
    evidenceDigest: string | null
  } | null
}

export type IntegrityStatus = 'VALID' | 'TAMPERED' | 'UNSIGNED' | 'UNKNOWN_KEY' | 'UNAVAILABLE' | 'NO_DECISION'

/** GET /claims/:id/decision/verify */
export interface DecisionIntegrity {
  claimId: string | null
  decisionId: string | null
  status: IntegrityStatus
  alg: string | null
  keyId: string | null
  bundleDigest: string | null
  recomputedDigest: string | null
}

/** GET /claims/:id/payout (masked). */
export interface PayoutView {
  claimedAmountCents: number | null
  destination: { bankName: string | null; accountHolder: string | null; accountLast4: string | null } | null
  decision: {
    id: string
    outcome: string
    approvedAmountCents: number | null
    decidedAt: string | null
    decidedByRole: string | null
  } | null
  payout: {
    id: string
    amountCents: number | null
    destinationLast4: string | null
    status: string | null
    initiatedAt: string | null
  } | null
}

/** GET /claims/:id/evidence → evidence[] */
export interface EvidenceItem {
  id: string
  displayName: string | null
  mimeType: string | null
  sizeBytes: number | null
  sha256: string | null
  createdAt: string | null
}

/** GET /claims/:id/evidence/:eid/verify */
export interface EvidenceVerifyResult {
  status: 'VALID' | 'TAMPERED'
  expectedHash: string | null
  actualHash: string | null
  reason: string | null
}

/** GET /tenant/audit and GET /admin/audit → events[] */
export interface AuditEvent {
  id: string
  occurredAt: string | null
  actorId: string | null
  actorRole: string | null
  action: string
  resourceType: string | null
  resourceId: string | null
  outcome: string | null
}

export interface AuditPage {
  events: AuditEvent[]
  nextBefore: string | null
}

export interface ScreeningMix {
  NORMAL: number
  ELEVATED: number
  HIGH: number
  unscreened: number
}

/** GET /admin/integrity (SUPERADMIN). */
export interface PlatformIntegrity {
  generatedAt: string | null
  windowDays: number | null
  decisions: { total: number; signed: number; unsigned: number; byKeyId: { keyId: string; count: number }[] }
  verificationsInWindow: Record<string, number>
  screening: ScreeningMix & {
    byExecution: Record<string, number>
    byModelVersion: { modelVersion: string; count: number }[]
  }
}

/** The screening/integrity part of GET /tenant/overview (INSURER_ADMIN). */
export interface TenantOverviewSummary {
  tenant: { id: string; name: string } | null
  generatedAt: string | null
  screening: ScreeningMix | null
  integrity: { signed: number; unsigned: number; verificationsInWindow: Record<string, number> } | null
}

/** GET /integrity/public-key */
export interface PublicKeyInfo {
  alg: string
  standard: string | null
  keyId: string
  bundleVersion: string | null
  context: string | null
  publicKey: string | null
}
