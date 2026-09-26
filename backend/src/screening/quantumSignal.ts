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

export const INTERPRETATIONS = ['NORMAL', 'UNUSUAL', 'HIGH_ANOMALY'] as const
export type Interpretation = (typeof INTERPRETATIONS)[number]

export interface RiskSignals {
  classicalAnomaly: number
  quantumAnomaly: number
  interpretation: Interpretation
  explanation: string
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
      'SELECT model_version, classical_anomaly, quantum_anomaly, interpretation, execution, computed_at FROM screening_signals WHERE claim_id = ?'
    )
    .bind(claimId)
    .first<SignalRow>()
  if (!row) return null
  if (!isInterpretation(row.interpretation)) return null
  if (row.execution !== 'simulator' && row.execution !== 'hardware') return null
  const inUnit = (n: unknown) => typeof n === 'number' && Number.isFinite(n) && n >= 0 && n <= 1
  if (!inUnit(row.classical_anomaly) || !inUnit(row.quantum_anomaly)) return null
  return {
    classicalAnomaly: row.classical_anomaly,
    quantumAnomaly: row.quantum_anomaly,
    interpretation: row.interpretation,
    explanation: EXPLANATIONS[row.interpretation],
    modelVersion: row.model_version,
    execution: row.execution,
    computedAt: row.computed_at,
    advisory: true,
  }
}
