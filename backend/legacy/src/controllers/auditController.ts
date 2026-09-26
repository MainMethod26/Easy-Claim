import { Context } from 'hono';
import { AuditService } from '../services/auditService';

export class AuditController {
  static async getHistory(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    const history = await AuditService.getHistory(c.env.DB, userId);
    return c.json({ history });
  }

  static async getAuditTrail(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    const trail = await AuditService.getAuditTrail(c.env.DB, userId);
    return c.json({ trail });
  }
}
