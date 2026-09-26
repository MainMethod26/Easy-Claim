import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

// All request schemas are .strict(): unknown keys (e.g. status, stage, riskScore,
// decision, userId, tenantId, approvedBy) are rejected with 400 instead of being silently
// accepted. Ownership, tenant and workflow fields are always set server-side.

const id = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/)

export const claimIdParam = z.object({ claimId: id })

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

/** Insurer decision. Only the outcome is recorded (as claims.status); see DECISION_SECURITY.md. */
export const decideSchema = z.object({ outcome: z.enum(['Approved', 'Rejected']) }).strict()

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
