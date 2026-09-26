import { Hono } from 'hono'
const router = new Hono()
router.get('/history', (c) => c.json({ history: [] }))
router.get('/audit-trail', (c) => c.json({ trail: [] }))
export default router
