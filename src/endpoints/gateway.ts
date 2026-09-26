import { Hono } from 'hono'
const router = new Hono()

router.get('/home', (c) => c.json({ 
  message: 'Welcome to EasyClaim SA',
  alerts: [
    "Your OUTsurance claim #claim_out_101 is being reviewed.",
    "Discovery Health updated their claim submission guidelines."
  ]
}))

router.get('/services/most-visited', (c) => c.json({ 
  data: [
    { service: 'Submit Medical Claim (Discovery)' },
    { service: 'View Life Policy (Sanlam)' },
    { service: 'Log Car Accident (OUTsurance)' }
  ] 
}))

router.get('/notifications', (c) => c.json({ 
  notifications: [
    { type: 'Update', message: 'Momentum Health approved your recent pharmacy claim.' },
    { type: 'Reminder', message: 'Old Mutual premium of R150 is due on the 1st.' }
  ] 
}))

router.get('/activity/recent', (c) => c.json({ 
  activity: [
    { date: '2023-10-15', action: 'Uploaded hospital invoice for Discovery Health.' },
    { date: '2023-10-10', action: 'Canceled mandate for old insurance provider.' }
  ] 
}))

export default router
