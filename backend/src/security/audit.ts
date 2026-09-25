import type { Context } from 'hono'
import type { AppEnv } from '../types'

export type AuditOutcome = 'success' | 'denied' | 'failure'

export interface AuditEvent {
  action: string
  resourceType: string
  resourceId?: string
  outcome: AuditOutcome
  // Keep details minimal: identifiers and state names only. Never tokens, secrets,
  // free-text claim narratives, ID numbers, or banking details.
  details?: Record<string, string | number | boolean | null>
}

/**
 * Appends a security audit event. Audit rows are insert-only: no route updates or
 * deletes them. This is separate from console application logs.
 */
export async function writeAuditEvent(c: Context<AppEnv>, event: AuditEvent): Promise<void> {
  const actor = c.get('actor')
  await c.env.DB.prepare(
    `INSERT INTO audit_events
       (id, occurred_at, actor_id, actor_role, action, resource_type, resource_id, outcome, request_id, details)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      crypto.randomUUID(),
      new Date().toISOString(),
      actor?.id ?? null,
      actor?.role ?? null,
      event.action,
      event.resourceType,
      event.resourceId ?? null,
      event.outcome,
      c.get('requestId') ?? null,
      event.details ? JSON.stringify(event.details) : null
    )
    .run()
}
