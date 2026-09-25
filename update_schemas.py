import re

with open('backend/src/endpoints/policy.ts', 'r') as f:
    content = f.read()

new_content = content.replace(
"""// POST Insurance Requirements (Standard Info per Insurance Type)
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
})""",
"""// POST Insurance Requirements (Category Specific)
router.post('/requirements', async (c) => {
  const body = await c.req.json().catch(() => ({}))
  const insuranceType = body.insurance_type;
  
  let capturedData: any = {};
  
  if (insuranceType === 'Mobile Device Insurance') {
    capturedData = {
      insurance_type: body.insurance_type,
      jurisdiction: body.jurisdiction || 'South Africa',
      regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA'],
      customer_identity_kyc: body.customer_identity_kyc,
      asset_specific_details: body.asset_specific_details,
      risk_and_underwriting: body.risk_and_underwriting,
      financial_and_settlement: body.financial_and_settlement
    }
  } else if (insuranceType === 'Home Insurance (Building Structure & Contents)') {
    capturedData = {
      insurance_type: body.insurance_type,
      jurisdiction: body.jurisdiction || 'South Africa',
      regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA', 'Short-Term Insurance Act'],
      customer_identity_kyc: body.customer_identity_kyc,
      property_and_asset_details: body.property_and_asset_details,
      risk_and_compliance: body.risk_and_compliance,
      financial_and_settlement: body.financial_and_settlement
    }
  } else if (insuranceType === 'Motor Vehicle Insurance') {
    capturedData = {
      insurance_type: body.insurance_type,
      jurisdiction: body.jurisdiction || 'South Africa',
      regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA', 'National Road Traffic Act'],
      customer_identity_kyc: body.customer_identity_kyc,
      asset_specific_details: body.asset_specific_details,
      risk_and_underwriting: body.risk_and_underwriting,
      legal_and_consent: body.legal_and_consent
    }
  } else {
    return c.json({ status: 'error', message: 'Unknown insurance type' }, 400);
  }

  return c.json({ 
    status: 'success', 
    message: `${insuranceType} requirements saved successfully.`, 
    data: capturedData,
    artifacts: {
      policySchedule: 'generated',
      certificateOfInsurance: 'generated',
      policyContract: 'generated'
    }
  })
})"""
)

with open('backend/src/endpoints/policy.ts', 'w') as f:
    f.write(new_content)
