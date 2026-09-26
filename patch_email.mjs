import fs from 'fs'
let code = fs.readFileSync('backend/src/endpoints/claimsInsurer.ts', 'utf8')

const importSearch = `import { verifyDecision } from '../security/integrity'`
const importReplace = `import { verifyDecision } from '../security/integrity'\nimport { sendEmailNotification } from '../services/messaging'`

const transitionSearch = `const t = await transitionClaim(c, claim, 'Paid', {`
const transitionReplace = `const t = await transitionClaim(c, claim, 'Paid', {`

// Wait, actually let's just find `if (!t.ok) return c.json({ error: t.error }, t.status)` inside the /pay route and add the email there.
const notifySearch = `  if (!t.ok) return c.json({ error: t.error }, t.status)

  return c.json({ status: 'paid', payoutId, amountCents: row.amount_cents })`

const notifyReplace = `  if (!t.ok) return c.json({ error: t.error }, t.status)

  // Dispatch Email Notification
  await sendEmailNotification(c.env, 'customer@example.com', 'Claim Paid!', \`Your claim \${claim.id} has been paid via Stripe.\`)

  return c.json({ status: 'paid', payoutId, amountCents: row.amount_cents })`

code = code.replace(importSearch, importReplace)
code = code.replace(notifySearch, notifyReplace)

fs.writeFileSync('backend/src/endpoints/claimsInsurer.ts', code)
