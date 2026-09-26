import { Hono } from 'hono';
import { Env } from '../types/env';
import { OcrController } from '../controllers/ocrController';

const router = new Hono<{ Bindings: Env }>();


router.post('/', OcrController.process);


export default router;
