import { Context } from 'hono';
import { PolicyService } from '../services/policyService';

export class PolicyController {
  static async getMyCovers(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    const policies = await PolicyService.getMyCovers(c.env.DB, userId);
    return c.json({ policies });
  }

  static getMarketCatalog(c: Context) {
    return c.json({ catalog: PolicyService.getMarketCatalog() });
  }

  static async joinRequest(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const userId = c.req.header('x-user-id') || 'user123';
    const result = await PolicyService.createJoinRequest(c.env.DB, userId, body);
    return c.json({ status: 'Requested', message: 'Join request forwarded to provider.', policyId: result.id });
  }

  static async saveRequirements(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const result = await PolicyService.processRequirements(c.env.DB, body);
    
    if (!result) {
      return c.json({ status: 'error', message: 'Unknown insurance type or missing policyId' }, 400);
    }

    return c.json({ 
      status: 'success', 
      message: `${body.insurance_type} requirements saved successfully.`, 
      data: result.capturedData,
      artifacts: {
        policySchedule: 'generated',
        certificateOfInsurance: 'generated',
        policyContract: 'generated'
      }
    });
  }
}
