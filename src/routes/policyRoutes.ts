import { Hono } from 'hono';
import { PolicyController } from '../controllers/policyController';

const router = new Hono();

router.get('/my-covers', PolicyController.getMyCovers);
router.get('/market-catalog', PolicyController.getMarketCatalog);
router.post('/join-request', PolicyController.joinRequest);
router.post('/requirements', PolicyController.saveRequirements);

export default router;
