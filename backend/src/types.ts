// Final role model (26 Sep 2026, decided by the team): CUSTOMER; insurer staff ASSESSOR and MANAGER
// (separation of duties: only a MANAGER decides and pays); INSURER_ADMIN manages its insurer's staff;
// SUPERADMIN runs the platform. See docs/ARCHITECTURE.md.
export const ROLES = ['CUSTOMER', 'ASSESSOR', 'MANAGER', 'INSURER_ADMIN', 'SUPERADMIN'] as const
export type Role = (typeof ROLES)[number]

/** Insurer staff who work claims (transitions). Their tokens MUST carry tenant_id. */
export const INSURER_ROLES: readonly Role[] = ['ASSESSOR', 'MANAGER']

/** Every role that belongs to one insurer tenant (tenant_id required in the token and in users). */
export const TENANT_ROLES: readonly Role[] = ['ASSESSOR', 'MANAGER', 'INSURER_ADMIN']

/** Roles an INSURER_ADMIN may create inside its own tenant. */
export const TENANT_STAFF_ROLES = ['ASSESSOR', 'MANAGER', 'INSURER_ADMIN'] as const

/** Identifier format shared by actor ids, tenant ids, claim ids and policy ids. */
export const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/

/**
 * The authenticated actor derived from a verified token (see security/actor.ts).
 *
 * - CUSTOMER: platform-level user; tenantId is always null (a customer holds policies
 *   with several insurers, see seed_sa_data.sql). Access is by ownership (claims.user_id).
 * - ASSESSOR: insurer staff; verifies, screens, reviews and requests information on its tenant's
 *   submitted claims. tenantId required.
 * - MANAGER: insurer staff; everything an assessor does plus decide, pay and re-open appeals.
 *   tenantId required.
 * - INSURER_ADMIN: the insurer's administrator; manages the tenant's staff accounts and sees its
 *   claims read-only. Never moves a claim. tenantId required.
 * - SUPERADMIN: platform operator; no tenant. Creates insurers and insurer admins, reads platform
 *   data. Never moves a claim. Cannot be created through the API.
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
  // Cloudflare Workers AI, used by the OCR queue consumer (endpoints/ocr.ts). Optional: without it
  // evidence OCR is skipped and logged. OCR output is stored as advisory text only.
  AI?: { run(model: string, input: Record<string, unknown>): Promise<{ response?: string; text?: string } | undefined> }
  // 'production' (wrangler.toml default) | 'development' | 'demo'. Anything other than
  // development/demo keeps the API docs (/swagger) switched off.
  ENVIRONMENT?: string
  // Local only: the password the demo accounts are seeded with (scripts/seed-demo-users.mjs,
  // test/setup.ts). The Worker itself never reads it.
  DEMO_LOGIN_PASSWORD?: string
}

export type AppEnv = {
  Bindings: Bindings
  Variables: {
    actor: Actor
    requestId: string
  }
}
