import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

// All request schemas are .strict(): unknown keys (e.g. status, stage, riskScore,
// decision, userId, tenantId, approvedBy) are rejected with 400 instead of being silently
// accepted. Ownership, tenant and workflow fields are always set server-side.

const id = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/)

export const claimIdParam = z.object({ claimId: id })

export const claimEvidenceParam = z.object({ claimId: id, evidenceId: id })

export const initiateClaimSchema = z
  .object({
    policyId: id,
    category: z.enum(['Medical', 'Vehicle', 'Life', 'Property', 'Other']).optional(),
  })
  .strict()

export const verifyEligibilitySchema = z.object({ policyId: id }).strict()

export const screeningSchema = z
  .object({
    causeOfLoss: z.string().trim().min(1).max(2000),
    incidentDate: z.iso.date().refine((d) => d <= new Date().toISOString().slice(0, 10), {
      message: 'incidentDate cannot be in the future',
    }),
  })
  .strict()

export const appealSchema = z.object({ reason: z.string().trim().min(1).max(2000) }).strict()

export const joinRequestSchema = z.object({ planId: id }).strict()

/** Amounts are integer cents; R1 000 000 cap keeps a typo from becoming a claim. */
const amountCents = z.number().int().min(1).max(100_000_000)

/**
 * Insurer decision (Phase 3). `approvedAmountCents` is only meaningful for Approved and may
 * never exceed the claimed amount (checked server-side); omitted = approve the full claimed
 * amount. Any other field (state, status, actor, payout data) is rejected.
 */
export const decideSchema = z
  .object({
    outcome: z.enum(['Approved', 'Rejected']),
    reason: z.string().trim().min(1).max(2000),
    approvedAmountCents: amountCents.optional(),
  })
  .strict()

/** Customer-supplied payout inputs, accepted only while the claim is still editable by its owner. */
export const payoutDetailsSchema = z
  .object({
    claimedAmountCents: amountCents,
    bankName: z.string().trim().min(2).max(100),
    accountHolder: z.string().trim().min(2).max(100),
    accountNumber: z.string().regex(/^[0-9]{6,20}$/),
  })
  .strict()

/** POST /pay takes no body: amount and destination are server-determined. */
export const emptyBodySchema = z.object({}).strict()

/** Pagination for list endpoints: bounded so a single request cannot dump a whole tenant. */
export const listQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
})

type Target = 'json' | 'param' | 'query'

/** zValidator with a uniform 400 body that lists field paths but never echoes input. */
export function validate<T extends z.ZodType>(target: Target, schema: T) {
  return zValidator(target, schema, (result, c) => {
    if (!result.success) {
      return c.json(
        {
          error: 'validation_failed',
          issues: result.error.issues.map((i) => ({ path: i.path.join('.'), code: i.code, message: i.message })),
        },
        400
      )
    }
  })
}
