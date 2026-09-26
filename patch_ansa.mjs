import fs from 'fs'
let code = fs.readFileSync('backend/src/endpoints/claimsInsurer.ts', 'utf8')

const search = `  // Real Payout via Stripe API
  let stripeStatus = 'simulated'
  if (c.env.STRIPE_SECRET_KEY) {
     console.log(\`Initiating real Stripe payout for claim \${claim.id}...\`)
     try {
       const stripeRes = await fetch('https://api.stripe.com/v1/transfers', {
         method: 'POST',
         headers: {
           'Authorization': \`Bearer \${c.env.STRIPE_SECRET_KEY}\`,
           'Content-Type': 'application/x-www-form-urlencoded'
         },
         body: new URLSearchParams({
           amount: decision.approved_amount_cents.toString(),
           currency: 'zar',
           destination: 'acct_123456789', // Mapped connected account
           description: \`Payout for claim \${claim.id}\`
         })
       })
       if (stripeRes.ok) stripeStatus = 'paid'
       else throw new Error(await stripeRes.text())
     } catch (err) {
       console.error('Stripe Payout failed:', err)
       return blocked('stripe_payout_failed', 500)
     }
  }`

const replace = `  // Real Payout via Ansa Payment API
  let ansaStatus = 'simulated'
  if (c.env.ANSA_SECRET_KEY) {
     console.log(\`Initiating real Ansa payout for claim \${claim.id}...\`)
     try {
       // Using Ansa's generic REST API for disbursements/payouts
       const ansaRes = await fetch('https://api.ansa.dev/v1/disbursements', {
         method: 'POST',
         headers: {
           'Authorization': \`Bearer \${c.env.ANSA_SECRET_KEY}\`,
           'Content-Type': 'application/json'
         },
         body: JSON.stringify({
           amount: decision.approved_amount_cents,
           currency: 'ZAR',
           destination_account: claim.payout_account_last4, // Mapped Ansa customer/account
           reference: \`Payout for claim \${claim.id}\`
         })
       })
       if (ansaRes.ok) ansaStatus = 'paid'
       else throw new Error(await ansaRes.text())
     } catch (err) {
       console.error('Ansa Payout failed:', err)
       return blocked('ansa_payout_failed', 500)
     }
  }`

code = code.replace(search, replace)
code = code.replace("status: stripeStatus,", "status: ansaStatus,")

fs.writeFileSync('backend/src/endpoints/claimsInsurer.ts', code)
