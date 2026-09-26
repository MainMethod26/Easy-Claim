import { Hono } from 'hono';
import { Env } from '../types/env';
import { GatewayController } from '../controllers/gatewayController';

const router = new Hono<{ Bindings: Env }>();


router.get('/', GatewayController.getHome);
router.get('/most-visited', GatewayController.getMostVisited);
router.get('/notifications', GatewayController.getNotifications);
router.get('/recent', GatewayController.getRecentActivity);


export default router;
