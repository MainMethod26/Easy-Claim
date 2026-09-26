import { Hono } from 'hono';
import { Env } from '../types/env';
import { PolicyController } from '../controllers/policyController';

const router = new Hono<{ Bindings: Env }>();


router.get('/', PolicyController.getMyCovers);
router.get('/market', PolicyController.getMarketCatalog);
router.post('/join', PolicyController.joinRequest);
router.post('/requirements', PolicyController.saveRequirements);


export default router;
