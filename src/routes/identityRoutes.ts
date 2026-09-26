import { Hono } from 'hono';
import { IdentityController } from '../controllers/identityController';

const router = new Hono();

router.get('/', IdentityController.getProfile);
router.patch('/', IdentityController.updateProfile);
router.get('/consent', IdentityController.getConsents);
router.get('/mandates/:tenantId/check', IdentityController.checkMandate);
router.post('/mandates/cancel', IdentityController.cancelMandate);
router.post('/login', IdentityController.login);

export default router;
