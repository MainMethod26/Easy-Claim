
import { Context } from 'hono';
import { OcrService } from '../services/ocrService';

export class OcrController {
  static process(c: Context) {
    const result = OcrService.processDocument();
    return c.json(result);
  }
}
