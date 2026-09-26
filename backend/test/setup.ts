import { applyD1Migrations } from 'cloudflare:test'
import { env } from 'cloudflare:workers'
import { DEMO_USERS } from '../src/security/demoUsers'
import { hashPassword } from '../src/security/password'

// Storage is isolated per test file, so this runs against a fresh database each time.
await applyD1Migrations(env.DB, env.TEST_MIGRATIONS)

const statements = env.TEST_SEED_SQL.split('\n')
  .filter((line) => !line.trim().startsWith('--'))
  .join('\n')
  .split(';')
  .map((s) => s.trim())
  .filter(Boolean)
await env.DB.batch(statements.map((s) => env.DB.prepare(s)))

// Demo accounts (same list the local seed script uses), all with the per-run DEMO_LOGIN_PASSWORD.
const hash = await hashPassword(env.DEMO_LOGIN_PASSWORD as string)
await env.DB.batch(
  DEMO_USERS.map((u) =>
    env.DB.prepare(
      "INSERT INTO users (id, username, password_hash, role, tenant_id, display_name, status, created_at, created_by) VALUES (?, ?, ?, ?, ?, ?, 'active', '2026-09-26T00:00:00Z', NULL)"
    ).bind(u.id, u.username, hash, u.role, u.tenantId, u.displayName)
  )
)
