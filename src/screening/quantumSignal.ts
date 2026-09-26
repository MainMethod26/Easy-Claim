/**
 * Phase 4 (quantum track): read-only adapter for advisory screening signals.
 *
 * The signal is produced offline by quantum/experiment.py (classical one-class SVM and a
 * quantum-kernel one-class SVM on identical features) and imported into `screening_signals`.
 * This module only READS that table. There is deliberately no write path in the Worker:
 * no request body, header or query parameter can set a score.
 *
 * The signal is screening context for a human. It never drives transitionClaim, RBAC,
 * tenant checks, evidence or payouts. See docs/quantum/QUANTUM_SCREENING_ARCHITECTURE.md.
 */
import { sha256Hex } from '../security/ledger'

export const INTERPRETATIONS = ['NORMAL', 'UNUSUAL', 'HIGH_ANOMALY'] as const
export type Interpretation = (typeof INTERPRETATIONS)[number]

/** Band vocabulary for reviewers (derived from the stored interpretation; storage is unchanged). */
export const ANOMALY_BANDS: Record<Interpretation, 'NORMAL' | 'ELEVATED' | 'HIGH'> = {
  NORMAL: 'NORMAL',
  UNUSUAL: 'ELEVATED',
  HIGH_ANOMALY: 'HIGH',
}
export type AnomalyBand = (typeof ANOMALY_BANDS)[Interpretation]

/** What the signal recommends to the human reviewer. Never an outcome. */
export type ScreeningRecommendation = 'STANDARD_REVIEW' | 'REVIEW_REQUIRED'

/** Worker-side contract version for how a stored signal is presented. */
export const SCREENING_VERSION = 'phase4-screening-v1'

/**
 * Versions of the offline pipeline that produced a model version (quantum/experiment.py).
 * Unknown model versions are reported as such rather than guessed.
 */
const PIPELINE_VERSIONS: Record<string, { features: string; kernel: string }> = {
  'phase4-qk1c-v1': { features: 'claim-features-v1', kernel: 'qk-fidelity-zz-r2-v1' },
}

export interface RiskSignals {
  classicalAnomaly: number
  quantumAnomaly: number
  interpretation: Interpretation
  /** NORMAL | ELEVATED | HIGH, from the quantum score's reference percentile. */
  anomalyBand: AnomalyBand
  /** STANDARD_REVIEW or REVIEW_REQUIRED. A human still decides; this never moves the claim. */
  screeningRecommendation: ScreeningRecommendation
  explanation: string
  /** Which logic produced this signal. */
  versions: { model: string; features: string; kernel: string; screening: string }
  /** SHA-256 over the stored row; recorded in audit and in the decision so later changes are detectable. */
  signalDigest: string
  modelVersion: string
  /** 'simulator' | 'hardware' — never claim hardware unless the row says so. */
  execution: 'simulator' | 'hardware'
  computedAt: string
  /** Always true: the signal informs review, it does not decide anything. */
  advisory: true
}

export const EXPLANATIONS: Record<Interpretation, string> = {
  NORMAL: 'The claim is structurally similar to the reference claim population.',
  UNUSUAL: 'The claim is somewhat unusual compared with the reference claim population.',
  HIGH_ANOMALY:
    'The claim is structurally unusual compared with the reference claim population. Suggest human review. This is a screening signal, not a fraud finding.',
}

interface SignalRow {
  claim_id: string
  feature_snapshot: string | null
  model_version: string
  classical_anomaly: number
  quantum_anomaly: number
  interpretation: string
  execution: string
  computed_at: string
}

function isInterpretation(v: string): v is Interpretation {
  return (INTERPRETATIONS as readonly string[]).includes(v)
}

/**
 * Returns the stored signal for a claim, or null when none has been computed.
 * Callers MUST have authorized the claim first (loadAuthorizedClaim); this function takes the
 * already-authorized claim id and performs no authorization of its own.
 * Rows that fail the shape checks are treated as absent rather than surfaced.
 */
export async function readRiskSignals(db: D1Database, claimId: string): Promise<RiskSignals | null> {
  const row = await db
    .prepare(
      'SELECT claim_id, model_version, classical_anomaly, quantum_anomaly, interpretation, execution, feature_snapshot, computed_at FROM screening_signals WHERE claim_id = ?'
    )
    .bind(claimId)
    .first<SignalRow>()
  if (!row) return null
  if (!isInterpretation(row.interpretation)) return null
  if (row.execution !== 'simulator' && row.execution !== 'hardware') return null
  const inUnit = (n: unknown) => typeof n === 'number' && Number.isFinite(n) && n >= 0 && n <= 1
  if (!inUnit(row.classical_anomaly) || !inUnit(row.quantum_anomaly)) return null
  const pipeline = PIPELINE_VERSIONS[row.model_version] ?? { features: 'unknown', kernel: 'unknown' }
  return {
    classicalAnomaly: row.classical_anomaly,
    quantumAnomaly: row.quantum_anomaly,
    interpretation: row.interpretation,
    anomalyBand: ANOMALY_BANDS[row.interpretation],
    screeningRecommendation: row.interpretation === 'NORMAL' ? 'STANDARD_REVIEW' : 'REVIEW_REQUIRED',
    explanation: EXPLANATIONS[row.interpretation],
    versions: { model: row.model_version, ...pipeline, screening: SCREENING_VERSION },
    signalDigest: await signalDigest(row),
    modelVersion: row.model_version,
    execution: row.execution,
    computedAt: row.computed_at,
    advisory: true,
  }
}

/** Canonical, order-fixed serialisation of a stored signal row, hashed with SHA-256. */
export async function signalDigest(row: SignalRow): Promise<string> {
  const canonical = JSON.stringify([
    row.claim_id,
    row.model_version,
    row.classical_anomaly,
    row.quantum_anomaly,
    row.interpretation,
    row.execution,
    row.computed_at,
    row.feature_snapshot ?? null,
  ])
  return sha256Hex(canonical)
}

/**
 * Compact form stored in claim_decisions.risk_signal and in audit details: what the reviewer
 * saw, with the digest that ties it to the stored row. No feature values.
 */
export function signalSummary(s: RiskSignals) {
  return {
    band: s.anomalyBand,
    recommendation: s.screeningRecommendation,
    classical: s.classicalAnomaly,
    quantum: s.quantumAnomaly,
    model: s.versions.model,
    execution: s.execution,
    digest: s.signalDigest,
  }
}
