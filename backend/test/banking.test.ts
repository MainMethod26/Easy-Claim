import { env } from 'cloudflare:workers'
import { describe, expect, it } from 'vitest'
import { destinationHash } from '../src/security/ledger'
import { assessorA, auditRows, call, customerA, customerB, managerA, signClaimConsent } from './helpers'

// Banking details live on the customer's profile (migrations/0017_customer_banking.sql): a new claim asks only
// for the amount, and the profile account is copied onto the claim at submission (or at the decision when the
// customer added it later). The full account number is hashed, never stored or returned.

const BANK = { bankName: 'Capitec', accountHolder: 'Mike Mokoena', accountNumber: '1234567890' }

async function draftWithAmount(as = customerA): Promise<string> {
  const res = await call('/claims/initiate', { method: 'POST', as, json: { policyId: 'pol_disc_001' } })
  const { claimId } = (await res.json()) as { claimId: string }
  await call(`/claims/${claimId}/screening`, { method: 'PATCH', as, json: { causeOfLoss: 'Hospital admission', incidentDate: '2026-01-10' } })
  const amount = await call(`/claims/${claimId}/amount`, { method: 'PUT', as, json: { claimedAmountCents: 250_000 } })
  expect(amount.status).toBe(200)
  return claimId
}

async function payoutView(claimId: string) {
  return (await (await call(`/claims/${claimId}/payout`, { as: customerA })).json()) as {
    claimedAmountCents: number
    destination: { bankName: string; accountHolder: string; accountLast4: string } | null
  }
}

describe('profile banking details', () => {
  it('saves one account per customer: masked back, hashed at rest, audited without the number', async () => {
    expect(await (await call('/covers/banking', { as: customerB })).json()).toEqual({ banking: null })
    expect((await call('/covers/banking', { method: 'PUT', as: customerB, json: { ...BANK, accountNumber: '12ab' } })).status).toBe(400)
    expect((await call('/covers/banking', { method: 'PUT', as: customerB, json: { ...BANK, extra: 'x' } })).status).toBe(400)

    const res = await call('/covers/banking', { method: 'PUT', as: customerB, json: BANK })
    expect(res.status).toBe(200)
    const text = await res.text()
    expect(text).not.toContain(BANK.accountNumber)
    expect(JSON.parse(text).banking).toMatchObject({ bankName: 'Capitec', accountHolder: 'Mike Mokoena', accountLast4: '7890' })

    const row = await env.DB.prepare('SELECT * FROM customer_banking WHERE user_id = ?').bind(customerB.id).first<Record<string, string>>()
    expect(JSON.stringify(row)).not.toContain(BANK.accountNumber)
    expect(row?.destination_hash).toBe(await destinationHash('Capitec', BANK.accountNumber))
    expect((await auditRows('customer.banking_saved', customerB.id)).length).toBe(1)
  })

  it('is customer-only', async () => {
    expect((await call('/covers/banking', { as: assessorA })).status).toBe(403)
    expect((await call('/covers/banking', { method: 'PUT', as: managerA, json: BANK })).status).toBe(403)
  })
})

describe('claims take the payout account from the profile', () => {
  it('a new claim needs only the amount; submission copies the profile account', async () => {
    await call('/covers/banking', { method: 'PUT', as: customerA, json: BANK })
    const claimId = await draftWithAmount()
    expect((await payoutView(claimId)).destination).toBeNull()

    const submit = await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
    expect(submit.status).toBe(200)
    expect(((await submit.json()) as { payoutAccount: unknown }).payoutAccount).toEqual({ bankName: 'Capitec', accountLast4: '7890' })

    const view = await payoutView(claimId)
    expect(view.claimedAmountCents).toBe(250_000)
    expect(view.destination).toEqual({ bankName: 'Capitec', accountHolder: 'Mike Mokoena', accountLast4: '7890' })

    // Changing the profile later does not move a claim that already has its destination.
    await call('/covers/banking', { method: 'PUT', as: customerA, json: { ...BANK, bankName: 'FNB', accountNumber: '5555000011' } })
    expect((await payoutView(claimId)).destination?.accountLast4).toBe('7890')
  })

  it('the amount is locked once submitted', async () => {
    const claimId = await draftWithAmount()
    await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
    expect((await call(`/claims/${claimId}/amount`, { method: 'PUT', as: customerA, json: { claimedAmountCents: 1 } })).status).toBe(409)
    expect((await call(`/claims/${claimId}/amount`, { method: 'PUT', as: customerB, json: { claimedAmountCents: 1 } })).status).toBe(404)
  })

  it('banking added after submission is picked up at the decision; without it an approval is refused', async () => {
    await env.DB.prepare('DELETE FROM customer_banking WHERE user_id = ?').bind(customerA.id).run()
    const claimId = await draftWithAmount()
    await call(`/claims/${claimId}/submit`, { method: 'POST', as: customerA })
    for (const step of ['verify', 'screen', 'review']) {
      expect((await call(`/claims/${claimId}/${step}`, { method: 'POST', as: assessorA })).status).toBe(200)
      if (step === 'verify') await signClaimConsent(claimId)
    }
    const approve = { outcome: 'Approved', reason: 'Covered event' }
    const refused = await call(`/claims/${claimId}/decide`, { method: 'POST', as: managerA, json: approve })
    expect(refused.status).toBe(422)
    expect(await refused.json()).toEqual({ error: 'payout_details_missing' })

    await call('/covers/banking', { method: 'PUT', as: customerA, json: BANK })
    const ok = await call(`/claims/${claimId}/decide`, { method: 'POST', as: managerA, json: approve })
    expect(ok.status).toBe(200)
    expect((await payoutView(claimId)).destination?.accountLast4).toBe('7890')
  })
})
