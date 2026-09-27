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
export const listQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(50).default(20),
    /** Cursor: the `nextBefore` value of the previous page (created_at|id of its last row). */
    before: z.string().regex(/^[0-9TZ:.+-]{0,40}\|[A-Za-z0-9_-]{1,64}$/).optional(),
    stage: z.enum(['Submitted', 'Verified', 'Screening', 'Review', 'Decision', 'Paid', 'Info Needed', 'Appeal', 'Withdrawn', 'Expired', 'Draft']).optional(),
  })
  .strict()

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

// ---- Accounts (team role model, 26 Sep 2026) ----
// Usernames are lower-cased by the handlers; the pattern keeps them URL- and log-safe.
const username = z.string().trim().regex(/^[A-Za-z0-9_-]{3,64}$/)
// Hackathon setting: 6 characters minimum so the agreed demo password works. Raise for production.
export const MIN_PASSWORD_LENGTH = 6
const password = z.string().min(MIN_PASSWORD_LENGTH).max(200)
const displayName = z.string().trim().min(2).max(100)

export const loginSchema = z.object({ username, password }).strict()
export const registerSchema = z.object({ username, password, displayName }).strict()

/** SUPERADMIN creates INSURER_ADMIN accounts for a tenant. Superadmins cannot be created via the API. */
export const adminCreateUserSchema = z
  .object({ username, password, displayName, role: z.literal('INSURER_ADMIN').default('INSURER_ADMIN'), tenantId: id })
  .strict()
/** INSURER_ADMIN creates staff (assessor, manager, another admin) for its own tenant; tenant from the token. */
export const tenantCreateUserSchema = z
  .object({ username, password, displayName, role: z.enum(['ASSESSOR', 'MANAGER', 'INSURER_ADMIN']) })
  .strict()
export const userStatusSchema = z.object({ status: z.enum(['active', 'disabled']) }).strict()
export const userIdParam = z.object({ userId: id })
export const createTenantSchema = z
  .object({ id: z.string().regex(/^ins_[a-z0-9_]{2,40}$/), name: z.string().trim().min(2).max(100) })
  .strict()
export const tenantQuerySchema = z.object({ tenantId: id.optional() })

// ---- Admin dashboards (read-only metrics, docs/admin/METRICS.md) ----
/** Reporting window in days, bounded so one request cannot scan unbounded history. */
export const metricsQuerySchema = z.object({ days: z.coerce.number().int().min(1).max(365).default(30) }).strict()
/** Audit log paging and filters. `before` is the `nextBefore` cursor of the previous page. */
const auditBase = {
  limit: z.coerce.number().int().min(1).max(100).default(50),
  before: z.iso.datetime().optional(),
  outcome: z.enum(['success', 'denied', 'failure']).optional(),
  action: z.string().regex(/^[a-z_.]{1,64}$/).optional(),
}
export const tenantAuditQuerySchema = z.object(auditBase).strict()
export const platformAuditQuerySchema = z.object({ ...auditBase, tenantId: id.optional() }).strict()

// ---- Insurer onboarding and policy linking (migration 0011) ----
const tenantIdSchema = z.string().regex(/^ins_[a-z0-9_]{2,40}$/)
const decisionReason = z.string().trim().min(5).max(500)
/** Public: an insurance company applies. FSP = FSCA financial services provider licence number. */
export const insurerApplicationSchema = z
  .object({
    companyName: z.string().trim().min(2).max(100),
    fspNumber: z.string().trim().regex(/^[0-9]{1,8}$/),
    contactEmail: z.email().max(254),
    adminUsername: username,
    adminDisplayName: displayName,
    password,
  })
  .strict()
export const applicationStatusQuerySchema = z.object({ status: z.enum(['pending', 'approved', 'rejected']).optional() }).strict()
export const applicationIdParam = z.object({ applicationId: id })
/** Approving names the new tenant id; the tenant's display name is the application's company name. */
export const approveApplicationSchema = z.object({ tenantId: tenantIdSchema }).strict()
export const rejectSchema = z.object({ reason: decisionReason }).strict()
/** Customer: link an existing policy by insurer + the insurer's policy number. */
export const linkRequestSchema = z.object({ tenantId: tenantIdSchema, policyNumber: z.string().trim().regex(/^[A-Za-z0-9-]{4,32}$/) }).strict()
export const linkRequestIdParam = z.object({ requestId: id })
/** Insurer admin approves with the plan name from its own records. */
export const approveLinkSchema = z.object({ planName: z.string().trim().min(2).max(100) }).strict()

// ---- Customer onboarding with documents (migration 0012) ----
/** Customer details shared with insurers they apply to. dateOfBirth is YYYY-MM-DD; the ID number is checked server-side. */
export const customerProfileSchema = z
  .object({
    legalName: z.string().trim().min(2).max(120),
    email: z.email().max(254),
    phone: z.string().trim().regex(/^\+?[0-9 ]{9,16}$/),
    dateOfBirth: z.iso.date(),
    idNumber: z.string().trim().regex(/^[0-9]{13}$/),
  })
  .strict()
export const linkStatusQuerySchema = z.object({ status: z.enum(['pending', 'more_info', 'approved', 'rejected']).optional() }).strict()
const docKey = z.string().regex(/^[a-z][a-z0-9_]{1,39}$/)
export const requestDocParam = z.object({ requestId: id, docKey })
export const verifyDocumentSchema = z.object({ verified: z.boolean() }).strict()
export const moreInfoSchema = z.object({ message: z.string().trim().min(5).max(500) }).strict()
export const requirementsSchema = z
  .object({
    items: z
      .array(z.object({ key: docKey, label: z.string().trim().min(2).max(80), required: z.boolean() }).strict())
      .max(10)
      .refine((items) => new Set(items.map((i) => i.key)).size === items.length, { message: 'duplicate keys' }),
  })
  .strict()
export const easyclaimIdQuerySchema = z.object({ easyclaimId: z.string().trim().toUpperCase().regex(/^EC-[0-9A-Z]{4}-[0-9A-Z]{4}$/) }).strict()
export const tenantIdParam = z.object({ tenantId: z.string().regex(/^ins_[a-z0-9_]{2,40}$/) })

// ---- Claim hand-offs (migration 0013) ----
const messageBody = z.string().trim().min(2).max(2000)
/** Staff: what information is needed (optional for older clients; the app always sends it). */
export const requestInfoSchema = z.object({ message: messageBody.optional() }).strict()
/** Customer: answer to an information request. */
export const respondSchema = z.object({ message: messageBody }).strict()
export const withdrawSchema = z.object({ reason: messageBody.optional() }).strict()
export const claimMessageSchema = z.object({ body: messageBody }).strict()

// ---- Account security (migration 0014) ----
export const changePasswordSchema = z
  .object({ currentPassword: z.string().min(1).max(200), newPassword: z.string().min(8).max(200) })
  .strict()
  .refine((v) => v.currentPassword !== v.newPassword, { message: 'new password must differ' })

// ---- POPIA consent forms (migration 0015) ----
export const consentIdParam = z.object({ consentId: id })
export const consentKindParam = z.object({ kind: z.enum(['onboarding', 'claim']) })
/** The insurer's own wording. Long enough to say purpose, sharing, retention and the right to withdraw. */
export const consentTemplateSchema = z.object({ body: z.string().trim().min(200).max(20000) }).strict()
/** Signing: explicit agreement, the full name on record, and the account password (re-authentication). */
export const signConsentSchema = z
  .object({ agree: z.literal(true), fullName: z.string().trim().min(2).max(120), password: z.string().min(1).max(200) })
  .strict()
export const consentResponseSchema = z.object({ reason: z.string().trim().min(2).max(500).optional() }).strict()
