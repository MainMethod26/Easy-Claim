import { Hono } from 'hono'
const router = new Hono()
router.get('/', (c) => c.json({ profile: {} }))
router.patch('/', (c) => c.json({ updated: true }))
router.get('/consent', (c) => c.json({ consent: true }))
router.get('/mandates/:tenantId/check', (c) => c.json({ active: true }))
router.post('/mandates/cancel', (c) => c.json({ cancelled: true }))
export default router
