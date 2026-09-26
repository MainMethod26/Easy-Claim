import fs from 'fs'
let code = fs.readFileSync('backend/src/endpoints/claimsInsurer.ts', 'utf8')
const search = `  const payoutId = \`pay_\${crypto.randomUUID()}\`
  const row = gatedInsert(c.env.DB, 'payouts', {`

const replace = `
  // Real Payout via Stripe API
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
  }

  const payoutId = \`pay_\${crypto.randomUUID()}\`
  const row = gatedInsert(c.env.DB, 'payouts', {`

code = code.replace(search, replace)
code = code.replace("status: 'simulated',", "status: stripeStatus,")

fs.writeFileSync('backend/src/endpoints/claimsInsurer.ts', code)
