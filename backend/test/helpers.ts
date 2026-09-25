import { createExecutionContext, waitOnExecutionContext } from 'cloudflare:test'
import { env } from 'cloudflare:workers'
import worker from '../src/index'
import type { Role } from '../src/types'

export const BASE = 'http://localhost/api/v1'

export interface CallOptions {
  as?: { id: string; role: Role | string }
  method?: string
  json?: unknown
  headers?: Record<string, string>
  env?: Partial<typeof env>
}

export async function call(path: string, opts: CallOptions = {}): Promise<Response> {
  const headers = new Headers(opts.headers)
  if (opts.as) {
    headers.set('X-Dev-Actor-Id', opts.as.id)
    headers.set('X-Dev-Actor-Role', opts.as.role)
  }
  let body: string | undefined
  if (opts.json !== undefined) {
    headers.set('Content-Type', 'application/json')
    body = JSON.stringify(opts.json)
  }
  const request = new Request(`${BASE}${path}`, { method: opts.method ?? 'GET', headers, body })
  const ctx = createExecutionContext()
  const response = await worker.fetch(request, { ...env, ...opts.env }, ctx)
  await waitOnExecutionContext(ctx)
  return response
}

export const customerA = { id: 'user123', role: 'CUSTOMER' } as const // owns claim_disc_101, claim_sanlam_102
export const customerB = { id: 'user456', role: 'CUSTOMER' } as const // owns no claims
export const assessor = { id: 'assessor1', role: 'ASSESSOR' } as const
export const manager = { id: 'manager1', role: 'MANAGER' } as const
export const admin = { id: 'admin1', role: 'ADMIN' } as const

export async function auditRows(action: string, resourceId?: string) {
  const sql = resourceId
    ? 'SELECT * FROM audit_events WHERE action = ? AND resource_id = ?'
    : 'SELECT * FROM audit_events WHERE action = ?'
  const stmt = env.DB.prepare(sql)
  const { results } = await (resourceId ? stmt.bind(action, resourceId) : stmt.bind(action)).all()
  return results as Record<string, unknown>[]
}

/** Creates a Draft claim for user123 with completed screening and returns its id. */
export async function createReadyDraft(): Promise<string> {
  const res = await call('/claims/initiate', { method: 'POST', as: customerA, json: { policyId: 'pol_disc_001' } })
  const { claimId } = (await res.json()) as { claimId: string }
  await call(`/claims/${claimId}/screening`, {
    method: 'PATCH',
    as: customerA,
    json: { causeOfLoss: 'Hospital admission', incidentDate: '2026-01-10' },
  })
  return claimId
}
