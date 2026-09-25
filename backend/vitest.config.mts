import path from 'node:path'
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
            // Tests exercise authorization through the dev actor stub.
            ALLOW_DEV_ACTOR_HEADERS: 'true',
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
