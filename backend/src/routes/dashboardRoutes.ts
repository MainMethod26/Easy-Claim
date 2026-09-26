import { Hono } from 'hono';
import { Env } from '../types/env';
import { DashboardController } from '../controllers/dashboardController';

const router = new Hono<{ Bindings: Env }>();
router.get('/', DashboardController.getDashboardData);
export default router;
