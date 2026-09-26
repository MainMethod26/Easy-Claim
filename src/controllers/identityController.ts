import { Context } from 'hono';
import { IdentityService } from '../services/identityService';

export class IdentityController {
  static async getProfile(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    const profile = await IdentityService.getProfile(c.env.DB, userId);
    return c.json({ profile });
  }

  static async updateProfile(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    const body = await c.req.json().catch(() => ({}));
    const updatedFields = await IdentityService.updateProfile(c.env.DB, userId, body);
    return c.json({ 
      status: 'success', 
      message: 'Profile updated successfully',
      updatedFields
    });
  }

  static async getConsents(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    const consents = await IdentityService.getConsents(c.env.DB, userId);
    return c.json({ consents });
  }

  static async checkMandate(c: Context) {
    const tenantId = c.req.param('tenantId') || '';
    const userId = c.req.header('x-user-id') || 'user123';
    const mandate = await IdentityService.checkMandate(c.env.DB, tenantId, userId);
    return c.json({ mandate });
  }

  static async cancelMandate(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const mandateId = body.mandateId || '';
    const result = await IdentityService.cancelMandate(c.env.DB, mandateId);
    return c.json(result);
  }

  static async login(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const result = await IdentityService.login(c.env.DB, body.idNumber);
    
    if (result) {
      return c.json(result);
    }
    return c.json({ status: 'error', message: 'Invalid SA ID number' }, 401);
  }
}
