import { Context } from 'hono';
import { GatewayService } from '../services/gatewayService';

export class GatewayController {
  static getHome(c: Context) {
    return c.json(GatewayService.getHomeData());
  }

  static getMostVisited(c: Context) {
    return c.json({ data: GatewayService.getMostVisitedServices() });
  }

  static getNotifications(c: Context) {
    return c.json({ notifications: GatewayService.getNotifications() });
  }

  static getRecentActivity(c: Context) {
    return c.json({ activity: GatewayService.getRecentActivity() });
  }
}
