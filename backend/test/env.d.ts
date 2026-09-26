import type { D1Migration } from 'cloudflare:test'
import type { Bindings } from '../src/types'

declare global {
  namespace Cloudflare {
    interface Env extends Bindings {
      TEST_MIGRATIONS: D1Migration[]
      TEST_SEED_SQL: string
    }
  }
}

// Vite raw-text imports (test/accounts.test.ts reads scripts/seed-demo-users.mjs as text).
declare module '*?raw' {
  const text: string
  export default text
}
