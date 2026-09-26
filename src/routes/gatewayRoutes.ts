import { Hono } from 'hono';
import { GatewayController } from '../controllers/gatewayController';

const router = new Hono();

router.get('/home', GatewayController.getHome);
router.get('/services/most-visited', GatewayController.getMostVisited);
router.get('/notifications', GatewayController.getNotifications);
router.get('/activity/recent', GatewayController.getRecentActivity);

export default router;
