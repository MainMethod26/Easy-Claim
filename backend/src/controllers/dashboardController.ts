import { Context } from 'hono';
import { DashboardService } from '../services/dashboardService';

export class DashboardController {
  static async getDashboardData(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    const data = await DashboardService.getDashboardData(c.env.DB, userId);
    return c.json(data);
  }
}
