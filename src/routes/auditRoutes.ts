import { Hono } from 'hono';
import { Env } from '../types/env';
import { AuditController } from '../controllers/auditController';

const router = new Hono<{ Bindings: Env }>();


router.get('/history', AuditController.getHistory);
router.get('/trail', AuditController.getAuditTrail);


export default router;
