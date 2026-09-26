import { Hono } from 'hono'
import { swaggerUI } from '@hono/swagger-ui'
import gatewayRoutes from './routes/gatewayRoutes'
import policyRoutes from './routes/policyRoutes'
import claimsRoutes from './routes/claimsRoutes'
import ocrRoutes from './routes/ocrRoutes'
import identityRoutes from './routes/identityRoutes'
import auditRoutes from './routes/auditRoutes'
import openapiData from './openapi.json'
import { Env } from './types/env'

const app = new Hono<{ Bindings: Env }>()

// Swagger UI Endpoint
app.get('/swagger', swaggerUI({ url: '/openapi.json' }))

// Serve OpenAPI JSON
app.get('/openapi.json', (c) => {
  return c.json(openapiData)
})

app.route('/api/v1/client', gatewayRoutes)
app.route('/api/v1/covers', policyRoutes)
app.route('/api/v1/claims', claimsRoutes)
app.route('/api/v1/ocr', ocrRoutes)
app.route('/api/v1/profile', identityRoutes)
app.route('/api/v1/activities', auditRoutes)

export default {
  fetch: app.fetch,
  async queue(batch: any, env: any): Promise<void> {}
}
