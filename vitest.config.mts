import path from 'node:path'
import { randomBytes } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-plugin'
import { defineConfig } from 'vitest/config'

export default defineConfig(async () => {
  const migrations = await readD1Migrations(path.join(import.meta.dirname, 'migrations'))
  const seedSql = readFileSync(path.join(import.meta.dirname, 'seed_sa_data.sql'), 'utf8')

  return {
    plugins: [
      cloudflareTest({
        wrangler: { configPath: './wrangler.toml' },
        miniflare: {
          bindings: {
            TEST_MIGRATIONS: migrations,
            TEST_SEED_SQL: seedSql,
            // Fresh test-only signing secret per run; tests mint real HS256 tokens with it
            // (test/helpers.ts reads env.JWT_SECRET), so no secret-shaped literal is committed.
            JWT_SECRET: randomBytes(32).toString('hex'),
            // Phase 5: fresh ML-DSA-65 key seed per run (no key material committed).
            MLDSA_SEED: randomBytes(32).toString('hex'),
            JWT_ISSUER: 'easyclaim-test',
            JWT_AUDIENCE: 'easyclaim-api',
            ALLOWED_ORIGINS: 'http://localhost:5173',
          },
        },
      }),
    ],
    test: {
      setupFiles: ['./test/setup.ts'],
    },
  }
})
