/**
 * Publishing change notices to the realtime hub (see hub.ts). Fire-and-forget after the change has
 * been committed: a notice that is lost only means a client refreshes later (clients also re-sync on
 * every reconnect), so publishing never delays or fails the request that made the change.
 *
 * Notices carry ids, stages and statuses only. Never put names, amounts, reasons, message bodies or
 * any other personal data in an event.
 */
import type { Context } from 'hono'
import type { AppEnv, Bindings } from '../types'

export type RealtimeEventType =
  | 'consent.updated'
  | 'claim.updated'
  | 'claim.message'
  | 'claim.evidence'
  | 'link.updated'
  | 'team.updated'
  | 'application.created'
  | 'session.revoked'

export interface RealtimeEvent {
  type: RealtimeEventType
  [key: string]: string | number | boolean | null | undefined
}

export type Audience = { user: string } | { tenant: string | null } | { platform: true }

export function channelName(a: Audience): string | null {
  if ('user' in a) return `user:${a.user}`
  if ('tenant' in a) return a.tenant ? `tenant:${a.tenant}` : null
  return 'platform'
}

function send(env: Bindings, channel: string, body: unknown): Promise<unknown> {
  const ns = env.REALTIME
  if (!ns) return Promise.resolve()
  return ns
    .get(ns.idFromName(channel))
    .fetch('https://realtime-hub/publish', { method: 'POST', body: JSON.stringify(body) })
    .catch((err) => console.warn(`realtime publish to ${channel} failed: ${err instanceof Error ? err.name : 'unknown'}`))
}

function later(c: Context<AppEnv>, work: Promise<unknown>) {
  try {
    c.executionCtx.waitUntil(work)
  } catch {
    // No execution context (e.g. called from a job): let it run.
    void work
  }
}

/** Notify one or more audiences that something changed. */
export function publish(c: Context<AppEnv>, audiences: Audience[], event: RealtimeEvent): void {
  if (!c.env.REALTIME) return
  const body = { event: { ...event, at: new Date().toISOString() } }
  const channels = [...new Set(audiences.map(channelName).filter((x): x is string => x !== null))]
  later(c, Promise.all(channels.map((ch) => send(c.env, ch, body))))
}

/**
 * An account was disabled, changed or its password changed: tell its open apps and close their live
 * connections at once (the next API call would be refused anyway, see security/actor.ts).
 */
export function revokeLive(c: Context<AppEnv>, user: { id: string; role: string; tenant_id: string | null }, reason: string): void {
  if (!c.env.REALTIME) return
  const audience: Audience =
    user.role === 'CUSTOMER' ? { user: user.id } : user.role === 'SUPERADMIN' ? { platform: true } : { tenant: user.tenant_id }
  const channel = channelName(audience)
  if (!channel) return
  later(c, send(c.env, channel, { event: { type: 'session.revoked', reason, at: new Date().toISOString() }, closeUser: user.id }))
}

/** Both sides of a policy-link request (the customer and the insurer's staff). */
export async function linkAudiences(db: D1Database, requestId: string): Promise<Audience[]> {
  const r = await db.prepare('SELECT user_id, tenant_id FROM policy_link_requests WHERE id = ?').bind(requestId).first<{ user_id: string; tenant_id: string }>()
  return r ? [{ user: r.user_id }, { tenant: r.tenant_id }] : []
}

/** Notify both sides that a policy-link request changed (`change` names what happened). */
export async function publishLink(c: Context<AppEnv>, requestId: string, change: string): Promise<void> {
  if (!c.env.REALTIME) return
  publish(c, await linkAudiences(c.env.DB, requestId), { type: 'link.updated', requestId, change })
}
