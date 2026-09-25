export const ROLES = ['CUSTOMER', 'ASSESSOR', 'MANAGER', 'ADMIN'] as const
export type Role = (typeof ROLES)[number]

export const INSURER_ROLES: readonly Role[] = ['ASSESSOR', 'MANAGER']

export interface Actor {
  id: string
  role: Role
}

export type Bindings = {
  DB: D1Database
  CLAIM_EVENTS: Queue
  RATE_LIMITER?: RateLimit
  // Comma-separated list of browser origins allowed by CORS. Empty = no cross-origin access.
  ALLOWED_ORIGINS?: string
  // LOCAL DEV ONLY. See src/security/actor.ts. Never set this in wrangler.toml.
  ALLOW_DEV_ACTOR_HEADERS?: string
}

export type AppEnv = {
  Bindings: Bindings
  Variables: {
    actor: Actor
    requestId: string
  }
}
