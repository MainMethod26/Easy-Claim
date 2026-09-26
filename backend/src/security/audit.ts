import type { Context } from 'hono'
import type { AppEnv } from '../types'

export type AuditOutcome = 'success' | 'denied' | 'failure'

export interface AuditEvent {
  action: string
  resourceType: string
  resourceId?: string
  outcome: AuditOutcome
  // Keep details minimal: identifiers and state names only. Never tokens, secrets,
  // free-text claim narratives, ID numbers, banking details, or another tenant's data.
  details?: Record<string, string | number | boolean | null>
}

const COLUMNS =
  '(id, occurred_at, actor_id, actor_role, actor_tenant_id, action, resource_type, resource_id, outcome, request_id, details)'

/**
 * Builds the INSERT for a security audit event so callers can run it on its own or inside a
 * D1 batch with the state change it records. With `onlyIfPreviousChanged`, the row is written
 * only when the statement immediately before it in the same batch changed exactly one row
 * (SQLite `changes()`), so an audit row can never exist without its state change.
 */
export function auditStatement(
  c: Context<AppEnv>,
  event: AuditEvent,
  opts: { onlyIfPreviousChanged?: boolean } = {}
): D1PreparedStatement {
  const actor = c.get('actor')
  const sql = opts.onlyIfPreviousChanged
    ? `INSERT INTO audit_events ${COLUMNS} SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? WHERE changes() = 1`
    : `INSERT INTO audit_events ${COLUMNS} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  return c.env.DB.prepare(sql).bind(
    crypto.randomUUID(),
    new Date().toISOString(),
    actor?.id ?? null,
    actor?.role ?? null,
    actor?.tenantId ?? null,
    event.action,
    event.resourceType,
    event.resourceId ?? null,
    event.outcome,
    c.get('requestId') ?? null,
    event.details ? JSON.stringify(event.details) : null
  )
}

/**
 * Appends a security audit event. Audit rows are insert-only: no route updates or
 * deletes them (enforced by triggers in migrations/0002_security.sql). This is separate
 * from console application logs.
 */
export async function writeAuditEvent(c: Context<AppEnv>, event: AuditEvent): Promise<void> {
  await auditStatement(c, event).run()
}
