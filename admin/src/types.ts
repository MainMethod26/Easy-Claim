export type Role = 'CUSTOMER' | 'ASSESSOR' | 'MANAGER' | 'INSURER_ADMIN' | 'SUPERADMIN'

export type TenantId = 
  | 'ins_discovery'
  | 'ins_sanlam'
  | 'ins_outsurance'
  | 'ins_momentum'
  | 'ins_oldmutual'

export interface TenantInfo {
  id: TenantId
  name: string
  code: string
  color: string
  logoText: string
}

export const TENANTS: Record<TenantId, TenantInfo> = {
  ins_discovery: {
    id: 'ins_discovery',
    name: 'Discovery Health & Life',
    code: 'DISC',
    color: '#00539B',
    logoText: 'Discovery',
  },
  ins_sanlam: {
    id: 'ins_sanlam',
    name: 'Sanlam Financial Solutions',
    code: 'SAN',
    color: '#0075C9',
    logoText: 'Sanlam',
  },
  ins_outsurance: {
    id: 'ins_outsurance',
    name: 'OUTsurance Insurance',
    code: 'OUT',
    color: '#00875A',
    logoText: 'OUTsurance',
  },
  ins_momentum: {
    id: 'ins_momentum',
    name: 'Momentum Metropolitan',
    code: 'MTM',
    color: '#D92D20',
    logoText: 'Momentum',
  },
  ins_oldmutual: {
    id: 'ins_oldmutual',
    name: 'Old Mutual South Africa',
    code: 'OM',
    color: '#008559',
    logoText: 'Old Mutual',
  },
}

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

export interface Claim {
  id: string
  policy_id: string
  tenant_id: TenantId
  stage: ClaimStage
  status: 'pending' | 'Approved' | 'Rejected'
  category?: string
  cause_of_loss?: string
  incident_date?: string
  claimed_amount_cents?: number | null
  payout_destination_hash?: string | null
  payout_account_last4?: string | null
  payout_bank_name?: string | null
  created_at: string
  updated_at: string
}

export interface RiskSignals {
  band: 'NORMAL' | 'ELEVATED' | 'HIGH_ANOMALY'
  recommendation: 'STANDARD_REVIEW' | 'REVIEW_REQUIRED'
  score_percentile: number
  classical_score_percentile: number
  model_version: string
  features_digest?: string
  signal_digest?: string
  created_at?: string
  execution?: string
}

export interface DecisionIntegrity {
  status: 'VALID' | 'TAMPERED' | 'UNSIGNED' | 'UNKNOWN_KEY' | 'UNAVAILABLE' | 'NO_DECISION'
  decisionId?: string | null
  keyId?: string | null
  algorithm?: string | null
  bundleDigest?: string | null
  tamperedFields?: string[]
  checkedAt?: string
  outcome?: 'Approved' | 'Rejected'
  reason?: string
  approvedAmountCents?: number
}

export interface EvidenceItem {
  id: string
  claim_id: string
  filename: string
  mime_type: string
  byte_size: number
  sha256_hash: string
  created_at: string
  integrityStatus?: 'VALID' | 'TAMPERED'
}

export interface TimelineEntry {
  stage: ClaimStage
  status: 'completed' | 'current' | 'upcoming'
  reached_at?: string
  actor?: string
}

export interface PayoutDetails {
  claimedAmountCents: number | null
  destination: {
    bankName: string | null
    accountHolder: string | null
    last4: string | null
  } | null
  decision: {
    outcome: string
    reason: string
    approvedAmountCents: number | null
    decidedAt: string
  } | null
  payout: {
    id: string
    amountCents: number
    status: string
    paidAt: string
  } | null
}

export interface AuthUser {
  id: string
  name: string
  role: Role
  tenantId: TenantId
  token: string
}
