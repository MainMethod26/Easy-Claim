import { Hono } from 'hono'

const router = new Hono()

router.get('/history', (c) => c.json({ 
  history: [
    { id: 'act_01', date: '2023-10-15T10:30:00Z', action: 'Uploaded hospital invoice for Discovery Health claim.' },
    { id: 'act_02', date: '2023-10-10T14:15:00Z', action: 'Canceled debit order mandate for OUTsurance.' },
    { id: 'act_03', date: '2023-09-01T09:00:00Z', action: 'Joined Sanlam Comprehensive Life Cover.' }
  ] 
}))

router.get('/audit-trail', (c) => c.json({ 
  trail: [
    { event: 'LOGIN_SUCCESS', ip: '197.85.12.34', location: 'Johannesburg, ZA', timestamp: '2023-10-16T08:00:00Z' },
    { event: 'DOCUMENT_UPLOAD', ip: '197.85.12.34', location: 'Johannesburg, ZA', timestamp: '2023-10-15T10:30:00Z' },
    { event: 'CONSENT_GRANTED', ip: '197.85.12.34', location: 'Johannesburg, ZA', timestamp: '2023-06-22T11:45:00Z' }
  ] 
}))

export default router
