/**
 * Claim messages (migration 0013): the words that travel with a hand-off. Staff say what they need
 * when they request information; the customer answers; the appeal reason and withdraw reason are
 * kept; and customer and claim staff can exchange general messages.
 *
 * Messages that belong to a stage change are written in the SAME D1 batch as the transition
 * (transitionClaim `extra`), gated on the stage change having applied, so a message never exists
 * without its transition and vice versa. Bodies never go into audit_events (free text); the audit
 * row records only that a message of a kind was posted.
 */
import type { Context } from 'hono'
import type { AppEnv } from '../types'
import type { ClaimRow } from '../security/claimAccess'

export type MessageKind = 'info_request' | 'customer_reply' | 'appeal' | 'withdraw' | 'message'

export interface ClaimMessageDto {
  id: string
  kind: MessageKind
  authorRole: string
  /** "You" for the viewer's own messages is decided by the client; ids of other parties are not exposed. */
  mine: boolean
  body: string
  createdAt: string
}

/** Max general messages per author per claim per hour (abuse brake; transitions are not counted). */
export const MESSAGES_PER_HOUR = 20

/**
 * INSERT for a message. With `gated`, it only applies when the statement just before it in the batch
 * changed exactly one row (use after the transition's gated audit insert).
 */
export function messageStatement(c: Context<AppEnv>, claim: ClaimRow, kind: MessageKind, body: string, gated: boolean): D1PreparedStatement {
  const actor = c.get('actor')
  const cols = '(id, claim_id, tenant_id, author_id, author_role, kind, body, created_at)'
  const sql = gated
    ? `INSERT INTO claim_messages ${cols} SELECT ?, ?, ?, ?, ?, ?, ?, ? WHERE changes() = 1`
    : `INSERT INTO claim_messages ${cols} VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  return c.env.DB.prepare(sql).bind(
    `msg_${crypto.randomUUID()}`,
    claim.id,
    claim.tenant_id,
    actor.id,
    actor.role,
    kind,
    body,
    new Date().toISOString()
  )
}

export async function listMessages(c: Context<AppEnv>, claimId: string, limit = 100): Promise<ClaimMessageDto[]> {
  const me = c.get('actor').id
  const { results } = await c.env.DB.prepare(
    'SELECT id, kind, author_id, author_role, body, created_at FROM claim_messages WHERE claim_id = ? ORDER BY created_at, id LIMIT ?'
  )
    .bind(claimId, limit)
    .all<{ id: string; kind: MessageKind; author_id: string; author_role: string; body: string; created_at: string }>()
  return results.map((m) => ({ id: m.id, kind: m.kind, authorRole: m.author_role, mine: m.author_id === me, body: m.body, createdAt: m.created_at }))
}

/** The most recent open information request (what the customer has to answer), if any. */
export async function latestInfoRequest(db: D1Database, claimId: string): Promise<{ body: string; createdAt: string } | null> {
  const row = await db
    .prepare("SELECT body, created_at FROM claim_messages WHERE claim_id = ? AND kind = 'info_request' ORDER BY created_at DESC, id DESC LIMIT 1")
    .bind(claimId)
    .first<{ body: string; created_at: string }>()
  return row ? { body: row.body, createdAt: row.created_at } : null
}

export async function recentMessageCount(db: D1Database, claimId: string, authorId: string): Promise<number> {
  const since = new Date(Date.now() - 3600_000).toISOString()
  const row = await db
    .prepare("SELECT count(*) AS n FROM claim_messages WHERE claim_id = ? AND author_id = ? AND kind = 'message' AND created_at >= ?")
    .bind(claimId, authorId, since)
    .first<{ n: number }>()
  return row?.n ?? 0
}
