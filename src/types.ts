export const ROLES = ['CUSTOMER', 'ASSESSOR', 'MANAGER', 'ADMIN'] as const
export type Role = (typeof ROLES)[number]

/** Roles that act on behalf of an insurer tenant. Their tokens MUST carry tenant_id. */
export const INSURER_ROLES: readonly Role[] = ['ASSESSOR', 'MANAGER']

/** Identifier format shared by actor ids, tenant ids, claim ids and policy ids. */
export const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/

/**
 * The authenticated actor derived from a verified token (see security/actor.ts).
 *
 * - CUSTOMER: platform-level user; tenantId is always null (a customer holds policies
 *   with several insurers, see seed_sa_data.sql). Access is by ownership (claims.user_id).
 * - ASSESSOR / MANAGER: insurer staff; tenantId is the insurer they work for and is
 *   required. Access is by tenant (claims.tenant_id).
 * - ADMIN: no claim access; tenantId optional (DECISION REQUIRED: platform vs tenant admin).
 */
export interface Actor {
  id: string
  role: Role
  tenantId: string | null
}

export type Bindings = {
  DB: D1Database
  CLAIM_EVENTS: Queue
  RATE_LIMITER?: RateLimit
  // Private evidence storage (Phase 2). Optional so the API degrades to 503 on evidence
  // routes instead of failing to boot when the binding is absent (see EVIDENCE_SECURITY.md).
  EVIDENCE_BUCKET?: R2Bucket
  // Comma-separated list of browser origins allowed by CORS. Empty = no cross-origin access.
  ALLOWED_ORIGINS?: string
  // HS256 signing secret, >= 32 characters. Secret binding only:
  // `wrangler secret put JWT_SECRET` in deployed environments, `.dev.vars` locally.
  JWT_SECRET?: string
  // Expected `iss` and `aud` claims (plain vars in wrangler.toml).
  JWT_ISSUER?: string
  JWT_AUDIENCE?: string
  // Phase 5: 32-byte hex seed for the ML-DSA-65 decision-signing key. Secret binding only
  // (`wrangler secret put MLDSA_SEED` deployed, `.dev.vars` locally). Missing -> decisions refused (fail closed).
  MLDSA_SEED?: string
}

export type AppEnv = {
  Bindings: Bindings
  Variables: {
    actor: Actor
    requestId: string
  }
}
