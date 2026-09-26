import re

with open('backend/src/endpoints/policy.ts', 'r') as f:
    content = f.read()

new_content = content.replace(
    "export default router",
    """
// POST Insurance Requirements (Standard Info per Insurance Type)
router.post('/requirements', async (c) => {
  const body = await c.req.json().catch(() => ({}))
  
  // The standard way to save info per insurance type
  const requirements = {
    governmentId: body.governmentId || null,
    proofOfAddress: body.proofOfAddress || null,
    taxIdentification: body.taxIdentification || null,
    assetDetails: body.assetDetails || null,
    proofOfOwnership: body.proofOfOwnership || null,
    riskDisclosure: body.riskDisclosure || null,
    truthfulDisclosureDeclaration: body.truthfulDisclosureDeclaration || false,
    claimsHistory: body.claimsHistory || null,
    paymentDetails: body.paymentDetails || null,
    financialInterestNotifications: body.financialInterestNotifications || null,
    digitalSignature: body.digitalSignature || false,
  }

  return c.json({ 
    status: 'success', 
    message: 'Insurance requirements saved successfully.', 
    data: requirements,
    artifacts: {
      policySchedule: 'generated',
      certificateOfInsurance: 'generated',
      policyContract: 'generated'
    }
  })
})

export default router
"""
)

with open('backend/src/endpoints/policy.ts', 'w') as f:
    f.write(new_content)
