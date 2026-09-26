import { Context } from 'hono';
import { PolicyService } from '../services/policyService';

export class PolicyController {
  static async getMyCovers(c: Context) {
    const db = (c.env as any).DB;
    const policies = await PolicyService.getMyCovers(db, 'user123');
    return c.json({ policies });
  }

  static getMarketCatalog(c: Context) {
    return c.json({ catalog: PolicyService.getMarketCatalog() });
  }

  static async joinRequest(c: Context) {
    const body = await c.req.json();
    return c.json({ status: 'Requested', message: 'Join request forwarded to provider.', body });
  }

  static async saveRequirements(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const capturedData = PolicyService.processRequirements(body);
    
    if (!capturedData) {
      return c.json({ status: 'error', message: 'Unknown insurance type' }, 400);
    }

    return c.json({ 
      status: 'success', 
      message: `${body.insurance_type} requirements saved successfully.`, 
      data: capturedData,
      artifacts: {
        policySchedule: 'generated',
        certificateOfInsurance: 'generated',
        policyContract: 'generated'
      }
    });
  }
}
