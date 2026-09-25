import { Hono } from 'hono'

const router = new Hono()

// GET Profile
router.get('/', (c) => c.json({ 
  profile: {
    id: 'user123',
    firstName: 'Sipho',
    lastName: 'Nkosi',
    idNumber: '8505125021087',
    email: 'sipho.nkosi@example.co.za',
    phone: '+27 82 123 4567',
    address: '123 Nelson Mandela Drive, Sandton, 2196',
    riskProfile: 'Low',
    kycStatus: 'Verified'
  }
}))

// PATCH Profile
router.patch('/', async (c) => {
  const body = await c.req.json().catch(() => ({}))
  return c.json({ 
    status: 'success', 
    message: 'Profile updated successfully',
    updatedFields: body
  })
})

// GET Consents (POPIA / Data Sharing)
router.get('/consent', (c) => c.json({ 
  consents: [
    { id: 'c_popia', name: 'POPIA Data Processing', status: 'Granted', date: '2023-01-15' },
    { id: 'c_marketing', name: 'Marketing Communications', status: 'Declined', date: '2023-01-15' },
    { id: 'c_medical', name: 'Medical Records Sharing (Discovery)', status: 'Granted', date: '2023-06-22' }
  ]
}))

// GET Mandates (Debit Orders)
router.get('/mandates/:tenantId/check', (c) => {
  const tenantId = c.req.param('tenantId');
  return c.json({ 
    tenantId: tenantId,
    mandateActive: true,
    amount: 'R 850.00',
    nextDeduction: '2023-11-01',
    bankName: 'Standard Bank',
    accountEnding: '4567'
  })
})

// POST Cancel Mandate
router.post('/mandates/cancel', async (c) => {
  return c.json({ 
    status: 'success',
    message: 'Debit order mandate successfully cancelled.',
    cancellationDate: new Date().toISOString()
  })
})

export default router
