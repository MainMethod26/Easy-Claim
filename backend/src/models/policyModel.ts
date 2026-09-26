export class PolicyModel {
  /** The caller's own policies, with the insurer (tenant) name for display. */
  static async getMyCovers(db: D1Database, userId: string) {
    const { results } = await db
      .prepare(
        `SELECT p.id, p.user_id, p.plan_name, p.status, p.tenant_id, p.policy_number, t.name AS insurer_name
         FROM policies p LEFT JOIN tenants t ON t.id = p.tenant_id
         WHERE p.user_id = ? ORDER BY p.id`
      )
      .bind(userId)
      .all()
    return results
  }
}
