import { describe, expect, it } from 'vitest'
import {
  destinationLabel,
  formatZAR,
  mapAuditPage,
  mapClaimDetail,
  mapClaimList,
  mapDecision,
  mapDecisionIntegrity,
  mapEvidenceList,
  mapEvidenceVerify,
  mapLoginResponse,
  mapPlatformIntegrity,
  mapRiskSignals,
  mapTimeline,
  parseStoredSession,
  payIdempotencyKey,
} from './mappers'

describe('mapLoginResponse', () => {
  const body = {
    token: 'jwt.abc',
    tokenType: 'Bearer',
    expiresIn: 3600,
    actor: { id: 'u1', username: 'manager_discovery', role: 'MANAGER', tenantId: 'ins_discovery', displayName: 'M', status: 'active' },
  }

  it('keeps only token and the backend actor, with expiry from expiresIn', () => {
    const s = mapLoginResponse(body, 1_000)
    expect(s).toEqual({
      token: 'jwt.abc',
      expiresAt: 1_000 + 3_600_000,
      actor: { id: 'u1', username: 'manager_discovery', role: 'MANAGER', tenantId: 'ins_discovery', displayName: 'M', status: 'active' },
    })
  })

  it('rejects a response without a token or with an unknown role (no default role)', () => {
    expect(mapLoginResponse({ ...body, token: '' })).toBeNull()
    expect(mapLoginResponse({ ...body, actor: { ...body.actor, role: 'GOD' } })).toBeNull()
    expect(mapLoginResponse({ ...body, actor: undefined })).toBeNull()
  })

  it('drops expired or malformed stored sessions (e.g. the old dev_token_ user object)', () => {
    const s = mapLoginResponse(body, 0)!
    expect(parseStoredSession(s, 10)).toEqual(s)
    expect(parseStoredSession(s, s.expiresAt! + 1)).toBeNull()
    expect(parseStoredSession({ id: 'manager_a1', name: 'x', role: 'MANAGER', tenantId: 'ins_discovery', token: 'dev_token_manager' })).toBeNull()
  })
})

describe('mapClaimList', () => {
  it('maps snake_case rows and never adds payout fields', () => {
    const list = mapClaimList({
      claims: [
        { id: 'claim_1', policy_id: 'pol_1', tenant_id: 'ins_discovery', stage: 'Review', status: 'Pending', category: 'Device', claimed_amount_cents: 420000, created_at: '2026-09-01T00:00:00Z', updated_at: '2026-09-02T00:00:00Z' },
        { id: 'claim_2', policy_id: 'pol_2', tenant_id: 'ins_discovery', stage: 'Submitted', status: 'Pending', category: null, claimed_amount_cents: null, created_at: '2026-09-01T00:00:00Z', updated_at: '2026-09-01T00:00:00Z' },
        { nonsense: true },
      ],
    })
    expect(list).toHaveLength(2)
    expect(list[0]).toEqual({
      id: 'claim_1',
      policyId: 'pol_1',
      tenantId: 'ins_discovery',
      stage: 'Review',
      status: 'Pending',
      category: 'Device',
      claimedAmountCents: 420000,
      createdAt: '2026-09-01T00:00:00Z',
      updatedAt: '2026-09-02T00:00:00Z',
    })
    expect(list[1].category).toBeNull()
    expect(list[1].claimedAmountCents).toBeNull()
  })
})

describe('mapClaimDetail', () => {
  const base = {
    id: 'claim_1',
    policyId: 'pol_1',
    planName: 'Gold',
    tenantId: 'ins_discovery',
    insurerName: 'Discovery Health',
    stage: 'Info Needed',
    status: 'Pending',
    category: 'Device',
    causeOfLoss: 'Stolen phone',
    incidentDate: '2026-09-10',
    claimedAmountCents: 420000,
    payoutDestination: { bankName: 'FNB', accountLast4: '1234' },
    createdAt: '2026-09-11T00:00:00Z',
    updatedAt: '2026-09-12T00:00:00Z',
    infoRequest: { body: 'Please upload the police report', createdAt: '2026-09-12T00:00:00Z' },
    appealReason: null,
  }

  it('maps GET /claims/:id including infoRequest and payout destination', () => {
    const d = mapClaimDetail({ claim: base })!
    expect(d.payoutDestination).toEqual({ bankName: 'FNB', accountLast4: '1234' })
    expect(d.incidentDate).toBe('2026-09-10')
    expect(d.causeOfLoss).toBe('Stolen phone')
    expect(d.infoRequest).toEqual({ body: 'Please upload the police report', createdAt: '2026-09-12T00:00:00Z' })
    expect(d.appealReason).toBeNull()
  })

  it('missing payout destination and incident date stay missing: no fake bank, digits or date', () => {
    const d = mapClaimDetail({ claim: { ...base, payoutDestination: null, incidentDate: null, causeOfLoss: null } })!
    expect(d.payoutDestination).toBeNull()
    expect(d.incidentDate).toBeNull()
    expect(d.causeOfLoss).toBeNull()
    expect(destinationLabel(d.payoutDestination)).toBeNull()
    expect(JSON.stringify(d)).not.toMatch(/Standard Bank|9842|2026-09-23/)
  })

  it('a destination without last4 is treated as absent', () => {
    expect(mapClaimDetail({ claim: { ...base, payoutDestination: { bankName: 'FNB' } } })!.payoutDestination).toBeNull()
  })

  it('maps the appeal reason', () => {
    const d = mapClaimDetail({ claim: { ...base, stage: 'Appeal', infoRequest: null, appealReason: { body: 'I disagree', createdAt: '2026-09-20T00:00:00Z' } } })!
    expect(d.appealReason?.body).toBe('I disagree')
    expect(d.infoRequest).toBeNull()
  })

  it('returns null for a body without id/stage', () => {
    expect(mapClaimDetail({ claim: { policyId: 'x' } })).toBeNull()
    expect(mapClaimDetail(null)).toBeNull()
  })
})

describe('mapTimeline', () => {
  it('uses completed/date from the backend', () => {
    const t = mapTimeline({
      claimId: 'claim_1',
      currentStage: 'Screening',
      timeline: [
        { stage: 'Submitted', date: '2026-09-01T00:00:00Z', completed: true },
        { stage: 'Verified', date: null, completed: true },
        { stage: 'Screening', date: null, completed: true },
        { stage: 'Review', date: null, completed: false },
      ],
    })
    expect(t.currentStage).toBe('Screening')
    expect(t.entries).toEqual([
      { stage: 'Submitted', completed: true, date: '2026-09-01T00:00:00Z' },
      { stage: 'Verified', completed: true, date: null },
      { stage: 'Screening', completed: true, date: null },
      { stage: 'Review', completed: false, date: null },
    ])
  })

  it('an unexpected body yields an empty timeline', () => {
    expect(mapTimeline({ foo: 1 })).toEqual({ currentStage: null, entries: [] })
  })
})

describe('mapRiskSignals', () => {
  const signal = {
    classicalAnomaly: 0.42,
    quantumAnomaly: 0.91,
    interpretation: 'HIGH_ANOMALY',
    anomalyBand: 'HIGH',
    screeningRecommendation: 'REVIEW_REQUIRED',
    explanation: 'The claim is structurally unusual.',
    versions: { model: 'phase4-qk1c-v1', features: 'claim-features-v1', kernel: 'qk-fidelity-zz-r2-v1', screening: 'phase4-screening-v1' },
    signalDigest: 'abc123',
    modelVersion: 'phase4-qk1c-v1',
    execution: 'simulator',
    computedAt: '2026-09-01T00:00:00Z',
    advisory: true,
  }

  it('maps the backend RiskSignals contract', () => {
    const r = mapRiskSignals({ claimId: 'claim_1', stage: 'Screening', riskSignals: signal })!
    expect(r.anomalyBand).toBe('HIGH')
    expect(r.quantumAnomaly).toBe(0.91)
    expect(r.classicalAnomaly).toBe(0.42)
    expect(r.modelVersion).toBe('phase4-qk1c-v1')
    expect(r.screeningRecommendation).toBe('REVIEW_REQUIRED')
    expect(r.execution).toBe('simulator')
    expect(r.explanation).toBe('The claim is structurally unusual.')
  })

  it('null when no signal was computed (no default NORMAL band)', () => {
    expect(mapRiskSignals({ claimId: 'claim_1', stage: 'Screening', riskSignals: null })).toBeNull()
  })

  it('rejects the old invented shape and out-of-range scores', () => {
    expect(mapRiskSignals({ riskSignals: { band: 'NORMAL', score_percentile: 14.2, model_version: 'pennylane-kernel-fidelity-v1.4' } })).toBeNull()
    expect(mapRiskSignals({ riskSignals: { ...signal, quantumAnomaly: 14.2 } })).toBeNull()
    expect(mapRiskSignals({ riskSignals: { ...signal, anomalyBand: 'HIGH_ANOMALY' } })).toBeNull()
  })
})

describe('decision + integrity', () => {
  it('maps /decision with and without a record', () => {
    expect(mapDecision({ decision: 'pending', record: null })).toEqual({ decision: 'pending', record: null })
    const d = mapDecision({
      decision: 'Approved',
      record: { id: 'dec_1', decidedAt: '2026-09-02T00:00:00Z', decidedByRole: 'MANAGER', reason: 'ok', approvedAmountCents: 1000, rulesVersion: 'v1', evidenceDigest: null },
    })!
    expect(d.record?.id).toBe('dec_1')
    expect(d.record?.approvedAmountCents).toBe(1000)
  })

  it('maps /decision/verify without inventing a key id or digest', () => {
    const i = mapDecisionIntegrity({
      claimId: 'claim_1',
      decisionId: 'dec_1',
      integrity: { status: 'UNSIGNED', alg: null, keyId: null, bundleDigest: null, recomputedDigest: 'ff00' },
    })!
    expect(i.status).toBe('UNSIGNED')
    expect(i.keyId).toBeNull()
    expect(i.bundleDigest).toBeNull()
    expect(i.recomputedDigest).toBe('ff00')
    expect(mapDecisionIntegrity({ claimId: 'c', decisionId: null, integrity: { status: 'NO_DECISION' } })!.status).toBe('NO_DECISION')
    expect(mapDecisionIntegrity({ integrity: { status: 'MAYBE' } })).toBeNull()
  })
})

describe('evidence', () => {
  it('maps the list without claiming a verification status', () => {
    const list = mapEvidenceList({
      evidence: [{ id: 'ev_1', display_name: 'report.pdf', mime_type: 'application/pdf', size_bytes: 1024, sha256: 'aa', created_at: '2026-09-01T00:00:00Z' }],
    })
    expect(list).toEqual([{ id: 'ev_1', displayName: 'report.pdf', mimeType: 'application/pdf', sizeBytes: 1024, sha256: 'aa', createdAt: '2026-09-01T00:00:00Z' }])
    expect(list[0]).not.toHaveProperty('integrityStatus')
  })

  it('maps the verify result', () => {
    expect(mapEvidenceVerify({ status: 'TAMPERED', evidenceId: 'ev_1', reason: 'object_missing' })).toEqual({
      status: 'TAMPERED',
      expectedHash: null,
      actualHash: null,
      reason: 'object_missing',
    })
    expect(mapEvidenceVerify({ error: 'not_found' })).toBeNull()
  })
})

describe('audit + platform', () => {
  it('maps camelCase audit events and the cursor', () => {
    const p = mapAuditPage({
      events: [{ id: 'a1', occurredAt: '2026-09-01T00:00:00Z', actorId: null, actorRole: 'CUSTOMER', action: 'claim.created', resourceType: 'claim', resourceId: 'claim_1', outcome: 'success' }],
      nextBefore: '2026-09-01T00:00:00Z',
    })
    expect(p.events[0]).toEqual({ id: 'a1', occurredAt: '2026-09-01T00:00:00Z', actorId: null, actorRole: 'CUSTOMER', action: 'claim.created', resourceType: 'claim', resourceId: 'claim_1', outcome: 'success' })
    expect(p.nextBefore).toBe('2026-09-01T00:00:00Z')
  })

  it('maps /admin/integrity', () => {
    const p = mapPlatformIntegrity({
      generatedAt: '2026-09-01T00:00:00Z',
      windowDays: 30,
      decisions: { total: 3, signed: 2, unsigned: 1, byKeyId: [{ keyId: 'mldsa65-abc', count: 2 }] },
      verificationsInWindow: { VALID: 4 },
      screening: { NORMAL: 5, ELEVATED: 1, HIGH: 0, unscreened: 2, byExecution: { simulator: 6 }, byModelVersion: [{ modelVersion: 'phase4-qk1c-v1', count: 6 }] },
    })!
    expect(p.decisions.signed).toBe(2)
    expect(p.decisions.byKeyId).toEqual([{ keyId: 'mldsa65-abc', count: 2 }])
    expect(p.screening.HIGH).toBe(0)
    expect(p.screening.byExecution).toEqual({ simulator: 6 })
    expect(mapPlatformIntegrity({ error: 'forbidden' })).toBeNull()
  })
})

describe('helpers', () => {
  it('formats missing money as a dash', () => {
    expect(formatZAR(null)).toBe('—')
    expect(formatZAR(undefined)).toBe('—')
  })

  it('pay idempotency key matches the Flutter app', () => {
    expect(payIdempotencyKey('claim_123')).toBe('pay-claim_123')
  })
})
