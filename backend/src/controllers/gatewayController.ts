import { Context } from 'hono';
import { GatewayService } from '../services/gatewayService';

export class GatewayController {
  static async getHome(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    return c.json(await GatewayService.getHomeData(c.env.DB, userId));
  }

  static async getMostVisited(c: Context) {
    return c.json({ data: GatewayService.getMostVisitedServices() });
  }

  static async getNotifications(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    return c.json({ notifications: await GatewayService.getNotifications(c.env.DB, userId) });
  }

  static async getRecentActivity(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    return c.json({ activity: await GatewayService.getRecentActivity(c.env.DB, userId) });
  }
}
