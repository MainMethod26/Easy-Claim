import { Hono } from 'hono';
import { OcrController } from '../controllers/ocrController';

const router = new Hono();

router.post('/process', OcrController.process);

export default router;
