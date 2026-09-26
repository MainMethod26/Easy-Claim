/**
 * Helpers for the insert-only ledgers written together with a claim stage change
 * (claim_decisions, payouts). See TransitionOptions.extra in claimAccess.ts.
 */

/**
 * Builds `INSERT INTO <table> (cols) SELECT ?, ?, ... WHERE changes() = 1`: inside a D1
 * batch the row is written only when the statement immediately before it changed exactly
 * one row. Chained after transitionClaim's gated audit INSERT, this means the ledger row
 * exists only if the stage change (and its audit row) applied.
 */
export function gatedInsert(
  db: D1Database,
  table: 'claim_decisions' | 'payouts',
  row: Record<string, string | number | null>
): D1PreparedStatement {
  const cols = Object.keys(row)
  const sql = `INSERT INTO ${table} (${cols.join(', ')}) SELECT ${cols.map(() => '?').join(', ')} WHERE changes() = 1`
  return db.prepare(sql).bind(...cols.map((k) => row[k]))
}

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input))
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

/** Canonical destination fingerprint: the full account number is hashed, never stored. */
export function destinationHash(bankName: string, accountNumber: string): Promise<string> {
  return sha256Hex(`${bankName.trim().toLowerCase()}|${accountNumber}`)
}

/** Version tag recorded on every decision so a later rules/model change is distinguishable. */
export const DECISION_RULES_VERSION = 'phase3-manual-v1'

/**
 * Digest of the evidence set a decision was taken on: SHA-256 over the sorted SHA-256 hashes
 * of every evidence item on the claim (Phase 2 stores one per upload). Null when the claim has
 * no evidence. Re-computable later from the `evidence` table, so a decision can be checked
 * against the evidence that existed at decision time.
 */
export async function evidenceDigest(db: D1Database, claimId: string): Promise<{ digest: string | null; count: number }> {
  const { results } = await db.prepare('SELECT sha256 FROM evidence WHERE claim_id = ? ORDER BY sha256').bind(claimId).all<{ sha256: string }>()
  if (results.length === 0) return { digest: null, count: 0 }
  return { digest: await sha256Hex(results.map((r) => r.sha256).join('\n')), count: results.length }
}

export interface DecisionRow {
  id: string
  claim_id: string
  tenant_id: string | null
  outcome: 'Approved' | 'Rejected'
  reason: string
  previous_stage: string
  claimed_amount_cents: number | null
  approved_amount_cents: number | null
  destination_hash: string | null
  actor_id: string
  actor_role: string
  decided_at: string
  request_id: string | null
  rules_version: string
  evidence_digest: string | null
  risk_signal: string | null
  integrity_signature: string | null
}

export interface PayoutRow {
  id: string
  claim_id: string
  tenant_id: string | null
  decision_id: string
  amount_cents: number
  destination_hash: string
  destination_last4: string
  status: 'simulated'
  idempotency_key: string | null
  initiated_by: string
  initiated_role: string
  initiated_at: string
  request_id: string | null
}

export function latestDecision(db: D1Database, claimId: string) {
  return db
    .prepare('SELECT * FROM claim_decisions WHERE claim_id = ? ORDER BY decided_at DESC, rowid DESC LIMIT 1')
    .bind(claimId)
    .first<DecisionRow>()
}

export function payoutFor(db: D1Database, claimId: string) {
  return db.prepare('SELECT * FROM payouts WHERE claim_id = ?').bind(claimId).first<PayoutRow>()
}
