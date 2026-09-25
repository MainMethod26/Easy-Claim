import { Context } from 'hono';
import { AuditService } from '../services/auditService';

export class AuditController {
  static getHistory(c: Context) {
    const history = AuditService.getHistory();
    return c.json({ history });
  }

  static getAuditTrail(c: Context) {
    const trail = AuditService.getAuditTrail();
    return c.json({ trail });
  }
}
