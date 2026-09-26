import type { Context, MiddlewareHandler } from 'hono'
import { verify } from 'hono/jwt'
import { ID_PATTERN, ROLES, type Actor, type AppEnv, type Role } from '../types'

/**
 * Authentication contract (Phase 1).
 *
 *   Authorization: Bearer <JWT>
 *
 * The token is verified, never merely decoded:
 *   - signature: HS256 with JWT_SECRET (pinned; any other `alg`, including `none`, is rejected)
 *   - iss must equal JWT_ISSUER, aud must contain JWT_AUDIENCE (all three settings are
 *     required; a missing one refuses every request rather than skipping the check)
 *   - exp and iat are REQUIRED (hono only checks them when present); exp must be in the
 *     future and at most MAX_TOKEN_TTL_SECONDS[role] away, nbf is checked when present
 *   - sub: actor id, role: one of ROLES, tenant_id: required for ASSESSOR/MANAGER,
 *     forbidden for CUSTOMER, optional for ADMIN
 *
 * Every failure returns null (401) with no detail. hono's Jwt* error messages embed the
 * raw token, so only the error class name is ever logged, and nothing is audited for
 * unauthenticated requests (no pre-auth database writes).
 *
 * There is no revocation list in Phase 1; the bounded lifetime and secret rotation are the
 * compensating controls. The Phase 0 X-Dev-Actor-* header stub has been removed; there is
 * no non-token path. Local development mints tokens with `npm run token`.
 * Future identity-provider path: hono/jwt verifyWithJwks (asymmetric keys, JWKS URL).
 */
export const JWT_ALG = 'HS256' as const
export const MIN_SECRET_BYTES = 32

/** Longest accepted remaining lifetime per role (privileged roles get shorter tokens). */
export const MAX_TOKEN_TTL_SECONDS: Record<Role, number> = {
  CUSTOMER: 24 * 3600,
  ASSESSOR: 8 * 3600,
  MANAGER: 8 * 3600,
  ADMIN: 8 * 3600,
}

const BEARER_TOKEN = /^Bearer\s+([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/i

export async function resolveActor(c: Context<AppEnv>): Promise<Actor | null> {
  const secret = typeof c.env.JWT_SECRET === 'string' ? c.env.JWT_SECRET.trim() : ''
  const { JWT_ISSUER: issuer, JWT_AUDIENCE: audience } = c.env
  if (new TextEncoder().encode(secret).byteLength < MIN_SECRET_BYTES || !issuer || !audience) {
    // Misconfiguration must never open the API. Operators see this in logs; clients see 401.
    console.error(`[${c.get('requestId')}] auth misconfigured: JWT_SECRET (>= 32 bytes), JWT_ISSUER and JWT_AUDIENCE are required`)
    return null
  }

  const header = c.req.header('Authorization')
  if (!header) return null
  const match = BEARER_TOKEN.exec(header.trim())
  if (!match) return null

  let payload: unknown
  try {
    payload = await verify(match[1], secret, { alg: JWT_ALG, iss: issuer, aud: audience })
  } catch (err) {
    console.warn(`[${c.get('requestId')}] token rejected: ${err instanceof Error ? err.name : 'unknown'}`)
    return null
  }
  const result = validateClaims(payload, Math.floor(Date.now() / 1000))
  if (!result.ok) {
    // A correctly signed token with out-of-policy claims points at an issuer misconfiguration;
    // the fixed reason token is logged (never the claims themselves).
    console.warn(`[${c.get('requestId')}] token rejected: claims:${result.reason}`)
    return null
  }
  return result.actor
}

export type ClaimRejectReason =
  | 'not_object'
  | 'missing_exp'
  | 'missing_iat'
  | 'bad_sub'
  | 'unknown_role'
  | 'expired'
  | 'ttl_exceeded'
  | 'bad_tenant'
  | 'customer_with_tenant'
  | 'staff_without_tenant'

export type ClaimValidation = { ok: true; actor: Actor } | { ok: false; reason: ClaimRejectReason }

/** Pure claim-set validation (no crypto). `now` is Unix seconds. */
export function validateClaims(payload: unknown, now: number): ClaimValidation {
  if (!payload || typeof payload !== 'object') return { ok: false, reason: 'not_object' }
  const { sub, role, tenant_id: tenant, exp, iat } = payload as Record<string, unknown>

  if (typeof exp !== 'number' || !Number.isFinite(exp)) return { ok: false, reason: 'missing_exp' }
  if (typeof iat !== 'number' || !Number.isFinite(iat)) return { ok: false, reason: 'missing_iat' }
  if (typeof sub !== 'string' || !ID_PATTERN.test(sub)) return { ok: false, reason: 'bad_sub' }
  if (typeof role !== 'string' || !(ROLES as readonly string[]).includes(role)) return { ok: false, reason: 'unknown_role' }
  const r = role as Role

  if (exp <= now) return { ok: false, reason: 'expired' }
  if (exp - now > MAX_TOKEN_TTL_SECONDS[r]) return { ok: false, reason: 'ttl_exceeded' }

  const tenantId = tenant === undefined || tenant === null ? null : tenant
  if (tenantId !== null && (typeof tenantId !== 'string' || !ID_PATTERN.test(tenantId))) return { ok: false, reason: 'bad_tenant' }
  if (r === 'CUSTOMER' && tenantId !== null) return { ok: false, reason: 'customer_with_tenant' }
  if ((r === 'ASSESSOR' || r === 'MANAGER') && tenantId === null) return { ok: false, reason: 'staff_without_tenant' }

  return { ok: true, actor: { id: sub, role: r, tenantId } }
}

/** Convenience wrapper used by tests: the Actor, or null when the claims are rejected. */
export function actorFromClaims(payload: unknown, now: number): Actor | null {
  const result = validateClaims(payload, now)
  return result.ok ? result.actor : null
}

export const requireActor: MiddlewareHandler<AppEnv> = async (c, next) => {
  const actor = await resolveActor(c)
  if (!actor) {
    c.header('WWW-Authenticate', 'Bearer realm="easyclaim"')
    return c.json({ error: 'unauthenticated' }, 401)
  }
  c.set('actor', actor)
  await next()
}
