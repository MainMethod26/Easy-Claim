export class AuditService {
  static async getHistory(db: D1Database, userId: string) {
    const { results } = await db.prepare('SELECT id, timestamp as date, event as action FROM audit_logs WHERE user_id = ? ORDER BY timestamp DESC LIMIT 50').bind(userId).all();
    return results;
  }

  static async getAuditTrail(db: D1Database, userId: string) {
    const { results } = await db.prepare('SELECT event, ip_address as ip, location, timestamp FROM audit_logs WHERE user_id = ? ORDER BY timestamp DESC LIMIT 50').bind(userId).all();
    return results;
  }
}
