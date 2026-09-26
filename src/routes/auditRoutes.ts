import { Hono } from 'hono';
import { AuditController } from '../controllers/auditController';

const router = new Hono();

router.get('/history', AuditController.getHistory);
router.get('/audit-trail', AuditController.getAuditTrail);

export default router;
