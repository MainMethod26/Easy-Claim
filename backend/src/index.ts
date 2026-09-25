import { Hono } from 'hono'
import gatewayRoutes from './routes/gatewayRoutes'
import policyRoutes from './routes/policyRoutes'
import claimsRoutes from './routes/claimsRoutes'
import ocrRoutes from './routes/ocrRoutes'
import identityRoutes from './routes/identityRoutes'
import auditRoutes from './routes/auditRoutes'

const app = new Hono()

app.route('/api/v1/client', gatewayRoutes)
app.route('/api/v1/covers', policyRoutes)
app.route('/api/v1/claims', claimsRoutes)
app.route('/api/v1/ocr', ocrRoutes)
app.route('/api/v1/profile', identityRoutes)
app.route('/api/v1/activities', auditRoutes)

export default {
  fetch: app.fetch,
  // Note: For queue process processing we might want to abstract this, but it's fine for now
  async queue(batch: any, env: any): Promise<void> {
    // Queue processing logic would go here if needed.
    // e.g., await OCRService.processBatch(batch, env);
  }
}
