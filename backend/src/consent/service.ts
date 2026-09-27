/**
 * POPIA consent / mandate forms (migration 0015).
 *
 *   onboarding: insurer admin checks every required document → sends the consent form → the customer
 *               signs → Approve unlocks (approvePolicyLink requires a signed form).
 *   claims:     assessor Verifies (documents checked) → the form is created in the same batch → the
 *               customer signs → Screening unlocks (transitionClaim enforces it for every route).
 *
 * The wording is the insurer's own (consent_templates, one row per saved version). Until an insurer
 * saves its own text, the built-in starter below is used (version 0), so a customer is never sent an
 * empty form. The rendered text is copied into the consent row with its SHA-256 at send time, so later
 * edits never change what a customer saw or signed.
 *
 * Signing is an ECTA ordinary electronic signature: the customer ticks agreement, types their full name
 * (must match the name on record) and re-enters their password. The server then seals the record
 * (who, what text hash, subject, when) with ML-DSA-65 under its own context string. The customer may
 * decline a pending form or withdraw a signed one (POPIA s11(2)(b)); further work on that subject
 * then stops until a new form is signed. Past processing stays on record.
 *
 * Free text (form body, reasons) never goes into audit_events.
 */
import type { Context } from 'hono'
import type { AppEnv } from '../types'
import { auditStatement, writeAuditEvent } from '../security/audit'
import { sha256Hex } from '../security/ledger'
import { LOCKOUT_FAILURES, LOCKOUT_WINDOW_MS, verifyPassword } from '../security/password'
import { getSigner, sealConsent, verifyConsentSeal, type IntegrityStatus } from '../security/integrity'
import { publish } from '../realtime/publish'

type C = Context<AppEnv>
const now = () => new Date().toISOString()

export type ConsentKind = 'onboarding' | 'claim'
export type SubjectType = 'policy_link' | 'claim'
export type ConsentStatus = 'pending' | 'signed' | 'declined' | 'withdrawn' | 'superseded'
export type ConsentOutcome<T> = { ok: true; value: T } | { ok: false; status: 400 | 401 | 404 | 409 | 429 | 503; error: string }

const kindFor = (s: SubjectType): ConsentKind => (s === 'policy_link' ? 'onboarding' : 'claim')

/** Placeholders an insurer can use in its own wording; filled in when a form is sent. */
export const PLACEHOLDERS = ['{{insurer}}', '{{customer}}', '{{easyclaimId}}', '{{subject}}', '{{date}}'] as const

// ------------------------------------------------------------------ starter wording

const STARTER: Record<ConsentKind, string> = {
  onboarding: `CONSENT TO PROCESS AND SHARE PERSONAL INFORMATION (POPIA)

I, {{customer}} (EasyClaim ID {{easyclaimId}}), give {{insurer}} my consent to process my personal information for {{subject}}.

1. Purpose. {{insurer}} will use my information to confirm my identity, link my policy to my EasyClaim account, administer that policy and handle future claims on it.
2. Information. My name, contact details, date of birth, South African ID number and the documents I uploaded (such as my ID document, proof of address and policy schedule). Where my cover relates to health, this includes health information, which is special personal information under section 26 of POPIA, and I give my explicit consent for it.
3. Sharing. {{insurer}} may share my information only as needed for this purpose: with its own staff, its service providers bound by confidentiality, its reinsurers, and where the law requires it. EasyClaim stores and transmits my information for {{insurer}}.
4. Retention. My information is kept only as long as needed for this purpose or as the law requires.
5. My rights. I may ask to see or correct my information, object to its processing, and withdraw this consent at any time in the EasyClaim app. Withdrawing does not affect processing that happened before, but {{insurer}} may then be unable to continue with my policy link or claims. I may complain to the Information Regulator (inforeg.org.za).
6. Voluntary. I give this consent voluntarily, and I have read and understood this form.

Signed electronically on {{date}}.`,
  claim: `CLAIM MANDATE AND CONSENT (POPIA)

I, {{customer}} (EasyClaim ID {{easyclaimId}}), authorise {{insurer}} to assess and settle {{subject}} and consent to the processing of my personal information for that purpose.

1. Mandate. {{insurer}} may assess this claim, verify the documents and evidence I provided with third parties where needed (for example service providers, assessors and financial institutions), and pay any approved amount into the bank account I gave for this claim.
2. Information. The claim details, evidence documents, my bank details for payment, and any health information in this claim, which is special personal information under section 26 of POPIA; I give my explicit consent for it.
3. Sharing. Only as needed for this claim: {{insurer}}'s staff and service providers bound by confidentiality, its reinsurers, fraud-prevention bodies where the law allows, and where the law requires it.
4. Retention. Kept only as long as needed for this claim or as the law requires.
5. My rights. I may see or correct my information and withdraw this consent at any time in the EasyClaim app. Withdrawing does not affect processing that happened before, but {{insurer}} may then be unable to continue with this claim. I may complain to the Information Regulator (inforeg.org.za).
6. I confirm that the information I gave for this claim is true and complete.

Signed electronically on {{date}}.`,
}

// ------------------------------------------------------------------ templates

export interface ConsentTemplateDto {
  kind: ConsentKind
  /** 0 = the built-in starter text (not yet replaced by the insurer). */
  version: number
  isStarter: boolean
  body: string
  updatedAt: string | null
}

export async function currentTemplate(db: D1Database, tenantId: string, kind: ConsentKind): Promise<ConsentTemplateDto> {
  const row = await db
    .prepare('SELECT version, body, created_at FROM consent_templates WHERE tenant_id = ? AND kind = ? ORDER BY version DESC LIMIT 1')
    .bind(tenantId, kind)
    .first<{ version: number; body: string; created_at: string }>()
  return row
    ? { kind, version: row.version, isStarter: false, body: row.body, updatedAt: row.created_at }
    : { kind, version: 0, isStarter: true, body: STARTER[kind], updatedAt: null }
}

export async function templatesFor(db: D1Database, tenantId: string) {
  return {
    onboarding: await currentTemplate(db, tenantId, 'onboarding'),
    claim: await currentTemplate(db, tenantId, 'claim'),
    placeholders: [...PLACEHOLDERS],
  }
}

/** Saves the insurer's wording as a new version. Forms already sent keep the text they were sent with. */
export async function saveTemplate(c: C, tenantId: string, kind: ConsentKind, body: string): Promise<ConsentTemplateDto> {
  const db = c.env.DB
  const cur = await currentTemplate(db, tenantId, kind)
  const version = cur.version + 1
  const at = now()
  await db.batch([
    db
      .prepare('INSERT INTO consent_templates (id, tenant_id, kind, version, body, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(`ctpl_${crypto.randomUUID()}`, tenantId, kind, version, body, c.get('actor').id, at),
    auditStatement(c, { action: 'consent.template_saved', resourceType: 'tenant', resourceId: tenantId, outcome: 'success', details: { kind, version } }, { onlyIfPreviousChanged: true }),
  ])
  return { kind, version, isStarter: false, body, updatedAt: at }
}

function render(body: string, vars: Record<string, string>): string {
  return body.replace(/\{\{(insurer|customer|easyclaimId|subject|date)\}\}/g, (_, k: string) => vars[k] ?? '')
}

/** Live notice to both sides that a form changed (ids and status only). */
export function publishConsent(c: C, r: { id: string; user_id: string; tenant_id: string; subject_type: string; subject_id: string }, status: string) {
  publish(c, [{ user: r.user_id }, { tenant: r.tenant_id }], {
    type: 'consent.updated',
    consentId: r.id,
    subjectType: r.subject_type,
    subjectId: r.subject_id,
    status,
  })
}

// ------------------------------------------------------------------ sending

interface SubjectFacts {
  tenantId: string
  userId: string
  subjectType: SubjectType
  subjectId: string
  subjectLabel: string
}

async function nameOnRecord(db: D1Database, userId: string): Promise<{ name: string; easyclaimId: string }> {
  const u = await db
    .prepare('SELECT u.display_name, u.easyclaim_id, p.legal_name FROM users u LEFT JOIN customer_profiles p ON p.user_id = u.id WHERE u.id = ?')
    .bind(userId)
    .first<{ display_name: string | null; easyclaim_id: string | null; legal_name: string | null }>()
  return { name: u?.legal_name || u?.display_name || '', easyclaimId: u?.easyclaim_id ?? '' }
}

/**
 * Builds the INSERT for a new pending form. With `gated`, it applies only when the statement before
 * it in the batch changed exactly one row (use after a transition's gated audit row). `OR IGNORE`
 * keeps it a no-op if the subject already has an open form (unique index).
 */
export async function consentInsert(c: C, s: SubjectFacts, gated: boolean): Promise<{ id: string; statement: D1PreparedStatement }> {
  const db = c.env.DB
  const [tpl, who, insurer] = await Promise.all([
    currentTemplate(db, s.tenantId, kindFor(s.subjectType)),
    nameOnRecord(db, s.userId),
    db.prepare('SELECT name FROM tenants WHERE id = ?').bind(s.tenantId).first<{ name: string }>(),
  ])
  const at = now()
  const body = render(tpl.body, {
    insurer: insurer?.name ?? s.tenantId,
    customer: who.name,
    easyclaimId: who.easyclaimId || 'not yet issued',
    subject: s.subjectLabel,
    date: 'the date recorded with my signature',
  })
  const id = `cns_${crypto.randomUUID()}`
  const cols = '(id, tenant_id, user_id, subject_type, subject_id, template_version, body, body_sha256, status, requested_by, requested_at)'
  const values = [id, s.tenantId, s.userId, s.subjectType, s.subjectId, tpl.version, body, await sha256Hex(body), c.get('actor').id, at]
  const statement = gated
    ? db.prepare(`INSERT OR IGNORE INTO consents ${cols} SELECT ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ? WHERE changes() = 1`).bind(...values)
    : db.prepare(`INSERT INTO consents ${cols} VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)`).bind(...values)
  return { id, statement }
}

async function openConsent(db: D1Database, subjectType: SubjectType, subjectId: string) {
  return db
    .prepare("SELECT id, status FROM consents WHERE subject_type = ? AND subject_id = ? AND status IN ('pending', 'signed')")
    .bind(subjectType, subjectId)
    .first<{ id: string; status: ConsentStatus }>()
}

/** Sends a form for a subject that has none open (first send, or after a decline or withdrawal). */
export async function sendConsent(c: C, s: SubjectFacts): Promise<ConsentOutcome<ConsentSummaryDto>> {
  const db = c.env.DB
  const open = await openConsent(db, s.subjectType, s.subjectId)
  if (open) return { ok: false, status: 409, error: open.status === 'signed' ? 'consent_already_signed' : 'consent_already_sent' }
  const { id, statement } = await consentInsert(c, s, false)
  try {
    await db.batch([
      statement,
      auditStatement(
        c,
        { action: 'consent.requested', resourceType: 'consent', resourceId: id, outcome: 'success', details: { subjectType: s.subjectType, subjectId: s.subjectId } },
        { onlyIfPreviousChanged: true }
      ),
    ])
  } catch (err) {
    if (String(err).includes('UNIQUE')) return { ok: false, status: 409, error: 'consent_already_sent' }
    throw err
  }
  publishConsent(c, { id, user_id: s.userId, tenant_id: s.tenantId, subject_type: s.subjectType, subject_id: s.subjectId }, 'pending')
  return { ok: true, value: (await latestConsent(c, s.subjectType, s.subjectId))! }
}

// ------------------------------------------------------------------ reading

interface ConsentRow {
  id: string
  tenant_id: string
  user_id: string
  subject_type: SubjectType
  subject_id: string
  template_version: number
  body: string
  body_sha256: string
  status: ConsentStatus
  requested_at: string
  signed_name: string | null
  signed_at: string | null
  signature_alg: string | null
  signature_key_id: string | null
  signature: string | null
  responded_at: string | null
  response_reason: string | null
  viewed_at: string | null
}

export interface ConsentSummaryDto {
  id: string
  subjectType: SubjectType
  subjectId: string
  status: ConsentStatus
  templateVersion: number
  requestedAt: string
  /** When the customer first opened the form (null = not yet read). */
  viewedAt: string | null
  signedName: string | null
  signedAt: string | null
  respondedAt: string | null
  /** Why the customer declined or withdrew (their own words). */
  reason: string | null
  /** Seal check for signed forms: VALID, TAMPERED, UNSIGNED, UNKNOWN_KEY or UNAVAILABLE. */
  seal: IntegrityStatus | null
}

export interface ConsentDetailDto extends ConsentSummaryDto {
  insurerName: string
  subjectLabel: string
  body: string
  bodySha256: string
  /** Name the customer must type to sign (their own name on record). Only for the customer's own view. */
  signAs?: string
}

async function sealOf(c: C, r: ConsentRow): Promise<IntegrityStatus | null> {
  if (!r.signed_at || !r.signed_name) return null
  // The text hash is recomputed from the stored body, so an edited body shows as TAMPERED too.
  const bodyHash = await sha256Hex(r.body)
  return verifyConsentSeal(
    c.env.MLDSA_SEED,
    { ...r, body_sha256: bodyHash, signed_name: r.signed_name, signed_at: r.signed_at },
    { alg: r.signature_alg, keyId: r.signature_key_id, signature: r.signature }
  )
}

async function toSummary(c: C, r: ConsentRow): Promise<ConsentSummaryDto> {
  return {
    id: r.id,
    subjectType: r.subject_type,
    subjectId: r.subject_id,
    status: r.status,
    templateVersion: r.template_version,
    requestedAt: r.requested_at,
    viewedAt: r.viewed_at,
    signedName: r.signed_name,
    signedAt: r.signed_at,
    respondedAt: r.responded_at,
    reason: r.response_reason,
    seal: await sealOf(c, r),
  }
}

async function subjectLabel(db: D1Database, r: Pick<ConsentRow, 'subject_type' | 'subject_id'>): Promise<string> {
  if (r.subject_type === 'policy_link') {
    const l = await db.prepare('SELECT policy_number FROM policy_link_requests WHERE id = ?').bind(r.subject_id).first<{ policy_number: string }>()
    return `linking policy ${l?.policy_number ?? ''}`.trim()
  }
  return `claim ${r.subject_id.replace(/^claim_/, '').slice(0, 8).toUpperCase()}`
}

async function toDetail(c: C, r: ConsentRow, forOwner: boolean): Promise<ConsentDetailDto> {
  const db = c.env.DB
  const insurer = await db.prepare('SELECT name FROM tenants WHERE id = ?').bind(r.tenant_id).first<{ name: string }>()
  const detail: ConsentDetailDto = {
    ...(await toSummary(c, r)),
    insurerName: insurer?.name ?? r.tenant_id,
    subjectLabel: await subjectLabel(db, r),
    body: r.body,
    bodySha256: r.body_sha256,
  }
  if (forOwner && r.status === 'pending') detail.signAs = (await nameOnRecord(db, r.user_id)).name
  return detail
}

const SELECT = 'SELECT * FROM consents'

async function latestRow(db: D1Database, subjectType: SubjectType, subjectId: string) {
  return db
    .prepare(`${SELECT} WHERE subject_type = ? AND subject_id = ? ORDER BY requested_at DESC, rowid DESC LIMIT 1`)
    .bind(subjectType, subjectId)
    .first<ConsentRow>()
}

/** The most recent form for a subject (any status), or null when none was ever sent. */
export async function latestConsent(c: C, subjectType: SubjectType, subjectId: string): Promise<ConsentSummaryDto | null> {
  const r = await latestRow(c.env.DB, subjectType, subjectId)
  return r ? toSummary(c, r) : null
}

/** Full text of the latest form, for insurer staff of the subject's tenant (caller checks access). */
export async function latestConsentDetail(c: C, subjectType: SubjectType, subjectId: string): Promise<ConsentDetailDto | null> {
  const r = await latestRow(c.env.DB, subjectType, subjectId)
  return r ? toDetail(c, r, false) : null
}

/** True when the latest form for the subject is signed (and not withdrawn). */
export async function isSigned(db: D1Database, subjectType: SubjectType, subjectId: string): Promise<boolean> {
  return (await latestRow(db, subjectType, subjectId))?.status === 'signed'
}

/**
 * Claim gate used by transitionClaim for forward moves (Screening, Review, Decision, Paid):
 * - leaving Verified needs a signed form;
 * - once a form exists, the latest must be signed (a decline or withdrawal stops further work).
 * Claims that went past Verified before consent forms existed have no row and are not blocked.
 */
export async function claimConsentBlock(db: D1Database, claimId: string, fromStage: string): Promise<'consent_required' | 'consent_withdrawn' | null> {
  const latest = await latestRow(db, 'claim', claimId)
  if (!latest) return fromStage === 'Verified' ? 'consent_required' : null
  if (latest.status === 'signed') return null
  return latest.status === 'withdrawn' ? 'consent_withdrawn' : 'consent_required'
}

/**
 * Onboarding withdrawal: new claims on a policy whose link consent was declined or withdrawn are
 * refused. Policies linked before consent forms existed (no row) are not affected.
 */
export async function policyConsentBlocked(db: D1Database, policyId: string): Promise<boolean> {
  const link = await db
    .prepare("SELECT id FROM policy_link_requests WHERE policy_id = ? AND status = 'approved' LIMIT 1")
    .bind(policyId)
    .first<{ id: string }>()
  if (!link) return false
  const latest = await latestRow(db, 'policy_link', link.id)
  return latest !== null && latest.status !== 'signed'
}

// ------------------------------------------------------------------ customer

export async function myConsents(c: C): Promise<ConsentDetailDto[]> {
  const db = c.env.DB
  const { results } = await db
    .prepare(`${SELECT} WHERE user_id = ? AND status <> 'superseded' ORDER BY requested_at DESC LIMIT 100`)
    .bind(c.get('actor').id)
    .all<ConsentRow>()
  return Promise.all(results.map((r) => toDetail(c, r, true)))
}

async function ownRow(c: C, consentId: string) {
  return c.env.DB.prepare(`${SELECT} WHERE id = ? AND user_id = ?`).bind(consentId, c.get('actor').id).first<ConsentRow>()
}

export async function myConsent(c: C, consentId: string): Promise<ConsentDetailDto | null> {
  const r = await ownRow(c, consentId)
  return r ? toDetail(c, r, true) : null
}

/**
 * The customer opens a form. The first open of a pending form records viewed_at (audited) and tells the
 * insurer live that the customer is reading it.
 */
export async function openMyConsent(c: C, consentId: string): Promise<ConsentDetailDto | null> {
  const r = await ownRow(c, consentId)
  if (!r) return null
  if (r.status === 'pending' && !r.viewed_at) {
    const at = now()
    const res = await c.env.DB.batch([
      c.env.DB.prepare("UPDATE consents SET viewed_at = ? WHERE id = ? AND user_id = ? AND status = 'pending' AND viewed_at IS NULL").bind(at, r.id, r.user_id),
      auditStatement(c, { action: 'consent.viewed', resourceType: 'consent', resourceId: r.id, outcome: 'success' }, { onlyIfPreviousChanged: true }),
    ])
    if (res[0].meta.changes === 1) {
      r.viewed_at = at
      publishConsent(c, r, 'viewed')
    }
  }
  return toDetail(c, r, true)
}

/** A form can only be answered while its subject is still open. */
async function subjectOpen(db: D1Database, r: ConsentRow): Promise<boolean> {
  if (r.subject_type === 'policy_link') {
    const l = await db.prepare('SELECT status FROM policy_link_requests WHERE id = ?').bind(r.subject_id).first<{ status: string }>()
    return !!l && l.status !== 'rejected'
  }
  const cl = await db.prepare('SELECT stage FROM claims WHERE id = ?').bind(r.subject_id).first<{ stage: string }>()
  return !!cl && !['Withdrawn', 'Expired', 'Paid'].includes(cl.stage)
}

const normaliseName = (s: string) => s.normalize('NFKC').trim().replace(/\s+/g, ' ').toLowerCase()

export async function signConsent(c: C, consentId: string, input: { fullName: string; password: string }): Promise<ConsentOutcome<ConsentDetailDto>> {
  const db = c.env.DB
  const actor = c.get('actor')
  const r = await ownRow(c, consentId)
  if (!r) return { ok: false, status: 404, error: 'not_found' }
  if (r.status !== 'pending') return { ok: false, status: 409, error: 'not_pending' }
  if (!(await subjectOpen(db, r))) return { ok: false, status: 409, error: 'subject_closed' }

  // Same brake as sign-in: repeated wrong passwords on consent forms lock signing for a while.
  const since = new Date(Date.now() - LOCKOUT_WINDOW_MS).toISOString()
  const recent = await db
    .prepare("SELECT count(*) AS n FROM audit_events WHERE action = 'consent.sign' AND outcome = 'denied' AND details = ? AND actor_id = ? AND occurred_at >= ?")
    .bind(JSON.stringify({ reason: 'password' }), actor.id, since)
    .first<{ n: number }>()
  if ((recent?.n ?? 0) >= LOCKOUT_FAILURES) return { ok: false, status: 429, error: 'too_many_attempts' }

  const user = await db.prepare('SELECT password_hash FROM users WHERE id = ?').bind(actor.id).first<{ password_hash: string }>()
  if (!(await verifyPassword(input.password, user?.password_hash))) {
    await writeAuditEvent(c, { action: 'consent.sign', resourceType: 'consent', resourceId: consentId, outcome: 'denied', details: { reason: 'password' } })
    return { ok: false, status: 401, error: 'invalid_credentials' }
  }
  const expected = (await nameOnRecord(db, actor.id)).name
  if (!expected || normaliseName(input.fullName) !== normaliseName(expected)) {
    await writeAuditEvent(c, { action: 'consent.sign', resourceType: 'consent', resourceId: consentId, outcome: 'denied', details: { reason: 'name_mismatch' } })
    return { ok: false, status: 400, error: 'name_mismatch' }
  }
  const signer = await getSigner(c.env.MLDSA_SEED)
  if (!signer) return { ok: false, status: 503, error: 'signing_unavailable' }

  const signedAt = now()
  const signedName = input.fullName.trim().replace(/\s+/g, ' ')
  const seal = await sealConsent(signer, { ...r, body_sha256: await sha256Hex(r.body), signed_name: signedName, signed_at: signedAt })
  const res = await db.batch([
    db
      .prepare(
        `UPDATE consents SET status = 'signed', signed_name = ?, signed_at = ?, signature_alg = ?, signature_key_id = ?, record_sha256 = ?, signature = ?, responded_at = ?
         WHERE id = ? AND user_id = ? AND status = 'pending'`
      )
      .bind(signedName, signedAt, seal.alg, seal.keyId, seal.recordSha256, seal.signature, signedAt, consentId, actor.id),
    auditStatement(
      c,
      { action: 'consent.sign', resourceType: 'consent', resourceId: consentId, outcome: 'success', details: { subjectType: r.subject_type, subjectId: r.subject_id, templateVersion: r.template_version } },
      { onlyIfPreviousChanged: true }
    ),
  ])
  if (res[0].meta.changes !== 1) return { ok: false, status: 409, error: 'not_pending' }
  publishConsent(c, r, 'signed')
  return { ok: true, value: (await myConsent(c, consentId))! }
}

/** Decline a pending form, or withdraw a signed one. The reason is optional and kept with the form. */
export async function respondNo(c: C, consentId: string, action: 'decline' | 'withdraw', reason: string | undefined): Promise<ConsentOutcome<ConsentDetailDto>> {
  const db = c.env.DB
  const actor = c.get('actor')
  const r = await ownRow(c, consentId)
  if (!r) return { ok: false, status: 404, error: 'not_found' }
  const from = action === 'decline' ? 'pending' : 'signed'
  const to = action === 'decline' ? 'declined' : 'withdrawn'
  const at = now()
  const res = await db.batch([
    db
      .prepare('UPDATE consents SET status = ?, responded_at = ?, response_reason = ? WHERE id = ? AND user_id = ? AND status = ?')
      .bind(to, at, reason ?? null, consentId, actor.id, from),
    auditStatement(
      c,
      { action: `consent.${action}`, resourceType: 'consent', resourceId: consentId, outcome: 'success', details: { subjectType: r.subject_type, subjectId: r.subject_id } },
      { onlyIfPreviousChanged: true }
    ),
  ])
  if (res[0].meta.changes !== 1) return { ok: false, status: 409, error: action === 'decline' ? 'not_pending' : 'not_signed' }
  publishConsent(c, r, to)
  return { ok: true, value: (await myConsent(c, consentId))! }
}
