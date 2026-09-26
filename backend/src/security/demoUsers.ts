import type { Role } from '../types'

/**
 * The demo accounts. LOCAL / DEMO ONLY: seeded by `npm run db:seed:users:local`
 * (scripts/seed-demo-users.mjs) and by the test setup, all with DEMO_LOGIN_PASSWORD from
 * backend/.dev.vars (the agreed demo password is 1234567). Never seed these on a Worker that
 * holds real data. The customer ids match policies.user_id / claims.user_id in seed_sa_data.sql.
 */
export interface DemoUser {
  id: string
  username: string
  role: Role
  tenantId: string | null
  displayName: string
}

export const DEMO_USERS: readonly DemoUser[] = [
  { id: 'usr_superadmin', username: 'superadmin', role: 'SUPERADMIN', tenantId: null, displayName: 'EasyClaim Platform Admin' },
  { id: 'usr_admin_discovery', username: 'admin_discovery', role: 'INSURER_ADMIN', tenantId: 'ins_discovery', displayName: 'Discovery Claims Admin' },
  { id: 'usr_admin_sanlam', username: 'admin_sanlam', role: 'INSURER_ADMIN', tenantId: 'ins_sanlam', displayName: 'Sanlam Claims Admin' },
  { id: 'user123', username: 'mike', role: 'CUSTOMER', tenantId: null, displayName: 'Mike' },
  { id: 'user456', username: 'lerato', role: 'CUSTOMER', tenantId: null, displayName: 'Lerato Nkosi' },
  { id: 'user789', username: 'sipho', role: 'CUSTOMER', tenantId: null, displayName: 'Sipho Dlamini' },
]
