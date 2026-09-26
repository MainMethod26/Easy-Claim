import { Context } from 'hono';
import { OcrService } from '../services/ocrService';

export class OcrController {
  static async process(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const result = await OcrService.processDocument(c.env.DB, body);
    return c.json(result);
  }
}
