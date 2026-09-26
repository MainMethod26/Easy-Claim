export class GatewayService {
  static async getHomeData(db: D1Database, userId: string) {
    const { results: activeClaims } = await db.prepare("SELECT * FROM claims WHERE user_id = ? AND status = 'Processing'").bind(userId).all();
    const alerts = activeClaims.map((c: any) => `Your claim #${c.id} is currently in stage: ${c.stage}.`);
    
    return { 
      message: 'Welcome to EasyClaim SA',
      alerts: alerts.length > 0 ? alerts : ["No active alerts. You're all caught up!"]
    };
  }
  
  static getMostVisitedServices() {
    return [
      { service: 'Submit Medical Claim (Discovery)' },
      { service: 'View Life Policy (Sanlam)' },
      { service: 'Log Car Accident (OUTsurance)' }
    ];
  }
  
  static async getNotifications(db: D1Database, userId: string) {
    const { results } = await db.prepare("SELECT event as message, timestamp as date FROM audit_logs WHERE user_id = ? AND event LIKE 'Notification:%' ORDER BY timestamp DESC LIMIT 5").bind(userId).all();
    return results;
  }
  
  static async getRecentActivity(db: D1Database, userId: string) {
    const { results } = await db.prepare("SELECT timestamp as date, event as action FROM audit_logs WHERE user_id = ? ORDER BY timestamp DESC LIMIT 5").bind(userId).all();
    return results;
  }
}
