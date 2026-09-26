import { applyD1Migrations } from 'cloudflare:test'
import { env } from 'cloudflare:workers'

// Storage is isolated per test file, so this runs against a fresh database each time.
await applyD1Migrations(env.DB, env.TEST_MIGRATIONS)

const statements = env.TEST_SEED_SQL.split('\n')
  .filter((line) => !line.trim().startsWith('--'))
  .join('\n')
  .split(';')
  .map((s) => s.trim())
  .filter(Boolean)
await env.DB.batch(statements.map((s) => env.DB.prepare(s)))
