import { Context } from 'hono';
import { IdentityService } from '../services/identityService';

export class IdentityController {
  static getProfile(c: Context) {
    return c.json({ profile: IdentityService.getProfile('user123') });
  }

  static async updateProfile(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const updatedFields = IdentityService.updateProfile(body);
    return c.json({ 
      status: 'success', 
      message: 'Profile updated successfully',
      updatedFields
    });
  }

  static getConsents(c: Context) {
    return c.json({ consents: IdentityService.getConsents() });
  }

  static checkMandate(c: Context) {
    const tenantId = c.req.param('tenantId') ?? '';
    return c.json(IdentityService.checkMandate(tenantId));
  }

  static async cancelMandate(c: Context) {
    return c.json(IdentityService.cancelMandate());
  }

  static async login(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const result = IdentityService.login(body.idNumber);
    
    if (result) {
      return c.json(result);
    }
    return c.json({ status: 'error', message: 'Invalid SA ID number' }, 401);
  }
}
