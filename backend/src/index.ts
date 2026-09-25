import { Hono } from 'hono'
import gateway from './endpoints/gateway'
import policy from './endpoints/policy'
import claims from './endpoints/claims'
import ocr from './endpoints/ocr'
import identity from './endpoints/identity'
import audit from './endpoints/audit'
import { processQueueBatch } from './endpoints/ocr'

const app = new Hono()

app.route('/api/v1/client', gateway)
app.route('/api/v1/covers', policy)
app.route('/api/v1/claims', claims)
app.route('/api/v1/ocr', ocr)
app.route('/api/v1/profile', identity)
app.route('/api/v1/activities', audit)

export default {
  fetch: app.fetch,
  async queue(batch: MessageBatch<any>, env: any): Promise<void> {
    await processQueueBatch(batch, env)
  }
}
