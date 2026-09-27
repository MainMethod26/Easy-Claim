import React, { useState, useEffect, useCallback } from 'react'
import type {
  ClaimDetail,
  DecisionInfo,
  DecisionIntegrity,
  EvidenceItem,
  EvidenceVerifyResult,
  PayoutView,
  RiskSignals,
  Role,
  Timeline,
} from '../types'
import { ApiService, describeError, type ActionResult } from '../services/api'
import { destinationLabel, formatDate, formatDateTime, formatZAR, NONE } from '../services/mappers'
import { stageBadgeClass } from './ClaimsTable'
import {
  X,
  ShieldCheck,
  CheckCircle2,
  Cpu,
  KeyRound,
  FileCheck,
  CreditCard,
  Lock,
  ArrowRight,
  BadgeAlert,
  MessageSquare,
  RotateCcw,
  Loader2,
} from 'lucide-react'

interface ClaimDetailDrawerProps {
  claimId: string
  role: Role
  onClose: () => void
  onClaimUpdated: () => void
}

type Load<T> = { state: 'loading' } | { state: 'ok'; data: T } | { state: 'error'; error: string }

const LOADING = { state: 'loading' } as const

function settle<T>(r: PromiseSettledResult<T>): Load<T> {
  return r.status === 'fulfilled' ? { state: 'ok', data: r.value } : { state: 'error', error: describeError(r.reason) }
}

const muted: React.CSSProperties = { fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }
const value: React.CSSProperties = { fontSize: '13px', fontWeight: 700, color: '#0F172A', wordBreak: 'break-word' }

const Field: React.FC<{ label: string; children: React.ReactNode }> = ({ label, children }) => (
  <div>
    <span style={muted}>{label}</span>
    <div style={value}>{children}</div>
  </div>
)

const LoadNote: React.FC<{ load: Load<unknown>; what: string }> = ({ load, what }) =>
  load.state === 'loading' ? (
    <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Loading {what}…</p>
  ) : load.state === 'error' ? (
    <p style={{ fontSize: '12px', color: '#B91C1C' }}>
      {what[0].toUpperCase() + what.slice(1)} not available: {load.error}
    </p>
  ) : null

function statusColors(ok: boolean | null) {
  if (ok === null) return { background: '#F1F5F9', color: '#475569', borderColor: '#CBD5E1' }
  return ok
    ? { background: '#ECFDF5', color: '#047857', borderColor: '#A7F3D0' }
    : { background: '#FEF2F2', color: '#DC2626', borderColor: '#FECACA' }
}

export const ClaimDetailDrawer: React.FC<ClaimDetailDrawerProps> = ({ claimId, role, onClose, onClaimUpdated }) => {
  const canAct = role === 'ASSESSOR' || role === 'MANAGER'
  const isManager = role === 'MANAGER'

  const [busy, setBusy] = useState(false)
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  const [detail, setDetail] = useState<Load<ClaimDetail | null>>(LOADING)
  const [timeline, setTimeline] = useState<Load<Timeline>>(LOADING)
  const [risk, setRisk] = useState<Load<RiskSignals | null>>(LOADING)
  const [decision, setDecision] = useState<Load<DecisionInfo | null>>(LOADING)
  const [integrity, setIntegrity] = useState<Load<DecisionIntegrity | null> | null>(null)
  const [payout, setPayout] = useState<Load<PayoutView | null>>(LOADING)
  const [evidence, setEvidence] = useState<Load<EvidenceItem[]>>(LOADING)
  const [evidenceChecks, setEvidenceChecks] = useState<Record<string, Load<EvidenceVerifyResult | null>>>({})

  // Decision form
  const [showDecisionModal, setShowDecisionModal] = useState(false)
  const [decisionOutcome, setDecisionOutcome] = useState<'Approved' | 'Rejected'>('Approved')
  const [decisionReason, setDecisionReason] = useState('')
  const [approvedAmountRands, setApprovedAmountRands] = useState('')

  // Request-info form
  const [showInfoModal, setShowInfoModal] = useState(false)
  const [infoMessage, setInfoMessage] = useState('')

  const loadDetails = useCallback(async () => {
    const [d, t, r, dec, p, ev] = await Promise.allSettled([
      ApiService.fetchClaimDetail(claimId),
      ApiService.fetchTimeline(claimId),
      // The backend gives the screening signal to ASSESSOR/MANAGER only.
      canAct ? ApiService.fetchRiskSignals(claimId) : Promise.resolve(null),
      ApiService.fetchDecision(claimId),
      ApiService.fetchPayout(claimId),
      ApiService.fetchEvidence(claimId),
    ])
    setDetail(settle(d))
    setTimeline(settle(t))
    setRisk(settle(r))
    setDecision(settle(dec))
    setPayout(settle(p))
    setEvidence(settle(ev))
    setEvidenceChecks({})
    // Verify the signature only when a signed decision record exists.
    if (dec.status === 'fulfilled' && dec.value?.record) {
      setIntegrity(LOADING)
      const [iv] = await Promise.allSettled([ApiService.verifyDecisionIntegrity(claimId)])
      setIntegrity(settle(iv))
    } else {
      setIntegrity(null)
    }
  }, [claimId, canAct])

  useEffect(() => {
    void loadDetails()
  }, [loadDetails])

  const runAction = async (fn: () => Promise<ActionResult>) => {
    setBusy(true)
    setActionMessage(null)
    setActionError(null)
    const res = await fn()
    setBusy(false)
    if (res.ok) {
      setActionMessage(res.message)
      onClaimUpdated()
      void loadDetails()
    } else {
      setActionError(res.message)
    }
    return res.ok
  }

  const claim = detail.state === 'ok' ? detail.data : null

  const handleDecisionSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    let approvedCents: number | undefined
    if (decisionOutcome === 'Approved' && approvedAmountRands.trim() !== '') {
      const rands = Number(approvedAmountRands)
      if (!Number.isFinite(rands) || rands <= 0) {
        setActionError('Enter a positive approved amount, or leave it empty to approve the claimed amount.')
        return
      }
      approvedCents = Math.round(rands * 100)
    }
    const ok = await runAction(() => ApiService.decideClaim(claimId, decisionOutcome, decisionReason.trim(), approvedCents))
    if (ok) {
      setShowDecisionModal(false)
      setDecisionReason('')
      setApprovedAmountRands('')
    }
  }

  const handleRequestInfo = async (e: React.FormEvent) => {
    e.preventDefault()
    const ok = await runAction(() => ApiService.requestInfo(claimId, infoMessage.trim()))
    if (ok) {
      setShowInfoModal(false)
      setInfoMessage('')
    }
  }

  const handlePay = () => {
    const pv = payout.state === 'ok' ? payout.data : null
    const amount = formatZAR(pv?.decision?.approvedAmountCents ?? null)
    const dest = destinationLabel(pv?.destination ?? null) ?? 'destination not reported'
    const confirmed = window.confirm(
      `Record a SIMULATED payout for ${claimId}?\n\nApproved amount: ${amount}\nDestination: ${dest}\n\nThe server pays only the signed, approved decision amount, once.`
    )
    if (confirmed) void runAction(() => ApiService.payClaim(claimId))
  }

  const handleVerifyIntegrity = async () => {
    setIntegrity(LOADING)
    const [iv] = await Promise.allSettled([ApiService.verifyDecisionIntegrity(claimId)])
    setIntegrity(settle(iv))
  }

  const handleVerifyEvidence = async (evidenceId: string) => {
    setEvidenceChecks((m) => ({ ...m, [evidenceId]: LOADING }))
    const [res] = await Promise.allSettled([ApiService.verifyEvidence(claimId, evidenceId)])
    setEvidenceChecks((m) => ({ ...m, [evidenceId]: settle(res) }))
  }

  const stage = claim?.stage ?? null
  const payoutView = payout.state === 'ok' ? payout.data : null
  const alreadyPaid = !!payoutView?.payout

  return (
    <div className="drawer-overlay" onClick={onClose}>
      <div className="drawer-content" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="drawer-header">
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
              <h2 style={{ fontSize: '18px', fontWeight: 800 }}>{claimId}</h2>
              {claim && <span className="mono-tag">{claim.policyId || NONE}</span>}
              {stage && <span className={`badge ${stageBadgeClass(stage)}`}>{stage}</span>}
            </div>
            {claim && (
              <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                {claim.category ?? 'Category not provided'} • Plan: <strong>{claim.planName ?? NONE}</strong> • Insurer:{' '}
                <strong>{claim.insurerName ?? claim.tenantId ?? NONE}</strong> • Status: <strong>{claim.status ?? NONE}</strong>
              </p>
            )}
          </div>

          <button className="btn btn-ghost" onClick={onClose} style={{ padding: '8px' }} aria-label="Close">
            <X size={18} />
          </button>
        </div>

        {/* Body */}
        <div className="drawer-body">
          {actionMessage && (
            <div role="status" style={{ padding: '12px 16px', background: '#ECFDF5', border: '1px solid #A7F3D0', borderRadius: '8px', color: '#047857', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <CheckCircle2 size={16} />
              <span>{actionMessage}</span>
            </div>
          )}
          {actionError && (
            <div role="alert" style={{ padding: '12px 16px', background: '#FEF2F2', border: '1px solid #FECACA', borderRadius: '8px', color: '#B91C1C', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <BadgeAlert size={16} />
              <span>{actionError}</span>
            </div>
          )}

          {detail.state !== 'ok' || !claim ? (
            <div className="panel">
              {detail.state === 'ok' ? (
                <p style={{ fontSize: '12px', color: '#B91C1C' }}>The claim detail response was not in the expected format.</p>
              ) : (
                <LoadNote load={detail} what="claim details" />
              )}
            </div>
          ) : (
            <>
              {/* Stepper from GET /timeline */}
              {timeline.state === 'ok' && timeline.data.entries.length > 0 ? (
                <div className="stepper-container">
                  {timeline.data.entries.map((s, idx, all) => {
                    const isCurrent = claim.stage === s.stage
                    return (
                      <React.Fragment key={s.stage}>
                        <div className={`step-node ${s.completed ? 'completed' : ''} ${isCurrent ? 'active' : ''}`} title={s.date ? `Reached ${formatDateTime(s.date)}` : 'No recorded date'}>
                          <div className="step-circle">{s.completed ? <CheckCircle2 size={16} /> : idx + 1}</div>
                          <span className="step-label">{s.stage}</span>
                        </div>
                        {idx < all.length - 1 && <div className={`step-connector ${s.completed ? 'completed' : ''}`} />}
                      </React.Fragment>
                    )
                  })}
                </div>
              ) : (
                <div className="panel">
                  <LoadNote load={timeline} what="timeline" />
                  {timeline.state === 'ok' && <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>No timeline returned.</p>}
                </div>
              )}

              {/* Messages from the customer / insurer */}
              {(claim.infoRequest || claim.appealReason) && (
                <div className="panel">
                  <div className="panel-header">
                    <span className="panel-title">
                      <MessageSquare size={16} color="var(--brand-orange)" />
                      Open requests
                    </span>
                  </div>
                  {claim.infoRequest && (
                    <div style={{ marginBottom: claim.appealReason ? '12px' : 0 }}>
                      <span style={muted}>Information requested from customer ({formatDateTime(claim.infoRequest.createdAt)})</span>
                      <p style={{ fontSize: '13px', color: '#334155', whiteSpace: 'pre-wrap' }}>{claim.infoRequest.body}</p>
                    </div>
                  )}
                  {claim.appealReason && (
                    <div>
                      <span style={muted}>Customer’s appeal reason ({formatDateTime(claim.appealReason.createdAt)})</span>
                      <p style={{ fontSize: '13px', color: '#334155', whiteSpace: 'pre-wrap' }}>{claim.appealReason.body}</p>
                    </div>
                  )}
                </div>
              )}

              {/* Loss details & payout destination (GET /claims/:id) */}
              <div className="panel">
                <div className="panel-header">
                  <span className="panel-title">
                    <FileCheck size={16} color="var(--brand-orange)" />
                    Loss details & payout destination
                  </span>
                  <span style={{ fontSize: '13px', fontWeight: 700, color: 'var(--brand-orange)' }}>
                    Claimed: {formatZAR(claim.claimedAmountCents)}
                  </span>
                </div>
                <p style={{ fontSize: '13px', color: '#334155', marginBottom: '14px', lineHeight: 1.5 }}>
                  {claim.causeOfLoss ?? 'Cause of loss not provided.'}
                </p>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', background: '#F8FAFC', border: '1px solid #E2E8F0', padding: '14px', borderRadius: '8px' }}>
                  <Field label="Incident date">{claim.incidentDate ?? 'Not provided'}</Field>
                  <Field label="Payout destination">{destinationLabel(claim.payoutDestination) ?? 'Not provided'}</Field>
                  <Field label="Filed">{formatDate(claim.createdAt)}</Field>
                  <Field label="Last updated">{formatDateTime(claim.updatedAt)}</Field>
                </div>
              </div>

              {/* Screening signal (GET /risk-signals) */}
              <div className="panel quantum-radar-card">
                <div className="panel-header">
                  <div className="panel-title" style={{ color: 'var(--quantum-cyan)' }}>
                    <Cpu size={18} />
                    <span>Screening signal (advisory)</span>
                  </div>
                  {risk.state === 'ok' && risk.data && (
                    <span className="badge" style={statusColors(risk.data.anomalyBand === 'NORMAL')}>{risk.data.anomalyBand}</span>
                  )}
                </div>

                {!canAct ? (
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Screening signals are shown to assessors and managers only.</p>
                ) : risk.state !== 'ok' ? (
                  <LoadNote load={risk} what="screening signal" />
                ) : !risk.data ? (
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>No screening signal has been computed for this claim.</p>
                ) : (
                  <>
                    <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '14px' }}>{risk.data.explanation || NONE}</p>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '12px', marginBottom: '12px' }}>
                      <Field label="Quantum-kernel anomaly">{risk.data.quantumAnomaly.toFixed(3)}</Field>
                      <Field label="Classical anomaly">{risk.data.classicalAnomaly.toFixed(3)}</Field>
                      <Field label="Recommendation">{risk.data.screeningRecommendation}</Field>
                    </div>
                    <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', fontSize: '11px', color: 'var(--text-muted)' }}>
                      <span>Model: <code className="mono-tag">{risk.data.modelVersion}</code></span>
                      <span>Execution: <code className="mono-tag">{risk.data.execution}</code></span>
                      <span>Computed: {formatDateTime(risk.data.computedAt)}</span>
                      {risk.data.signalDigest && <span>Digest: <code className="mono-tag">{risk.data.signalDigest.slice(0, 16)}…</code></span>}
                    </div>
                    <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '8px' }}>
                      Advisory only: the signal never moves the claim or decides an outcome.
                    </p>
                  </>
                )}
              </div>

              {/* Decision + signature (GET /decision, GET /decision/verify) */}
              <div className="panel pqc-shield-card">
                <div className="panel-header">
                  <div className="panel-title" style={{ color: 'var(--pqc-purple)' }}>
                    <KeyRound size={18} />
                    <span>Decision & signature</span>
                  </div>
                  {integrity?.state === 'ok' && integrity.data && (
                    <span className="badge" style={statusColors(integrity.data.status === 'VALID' ? true : integrity.data.status === 'NO_DECISION' ? null : false)}>
                      {integrity.data.status}
                    </span>
                  )}
                </div>

                {decision.state !== 'ok' ? (
                  <LoadNote load={decision} what="decision" />
                ) : !decision.data ? (
                  <p style={{ fontSize: '12px', color: '#B91C1C' }}>Decision response was not in the expected format.</p>
                ) : (
                  <>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px', marginBottom: '12px' }}>
                      <Field label="Decision">{decision.data.decision}</Field>
                      {decision.data.record && (
                        <>
                          <Field label="Approved amount">{formatZAR(decision.data.record.approvedAmountCents)}</Field>
                          <Field label="Decided">{formatDateTime(decision.data.record.decidedAt)}</Field>
                          <Field label="Decided by role">{decision.data.record.decidedByRole ?? NONE}</Field>
                        </>
                      )}
                    </div>
                    {decision.data.record?.reason && (
                      <p style={{ fontSize: '13px', color: '#334155', marginBottom: '12px' }}>
                        <span style={muted}>Reason: </span>
                        {decision.data.record.reason}
                      </p>
                    )}
                    {!decision.data.record && decision.data.decision !== 'pending' && (
                      <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '12px' }}>
                        No decision record exists (decided before decision records were kept), so there is nothing to verify.
                      </p>
                    )}
                  </>
                )}

                {integrity && (
                  integrity.state !== 'ok' ? (
                    <LoadNote load={integrity} what="signature verification" />
                  ) : !integrity.data ? (
                    <p style={{ fontSize: '12px', color: '#B91C1C' }}>Verification response was not in the expected format.</p>
                  ) : (
                    <div style={{ background: '#FFFFFF', padding: '12px', borderRadius: '8px', border: '1px solid #DDD6FE', marginBottom: '12px', fontSize: '12px', display: 'grid', gap: '6px' }}>
                      <div><span style={{ color: 'var(--text-muted)' }}>Algorithm:</span> <strong>{integrity.data.alg ?? NONE}</strong></div>
                      <div><span style={{ color: 'var(--text-muted)' }}>Key ID:</span> <code className="mono-tag">{integrity.data.keyId ?? NONE}</code></div>
                      <div><span style={{ color: 'var(--text-muted)' }}>Signed bundle digest:</span> <code className="mono-tag" style={{ wordBreak: 'break-all' }}>{integrity.data.bundleDigest ?? NONE}</code></div>
                      <div><span style={{ color: 'var(--text-muted)' }}>Recomputed digest:</span> <code className="mono-tag" style={{ wordBreak: 'break-all' }}>{integrity.data.recomputedDigest ?? NONE}</code></div>
                    </div>
                  )
                )}

                {decision.state === 'ok' && decision.data?.record && (
                  <button className="btn btn-pqc" style={{ fontSize: '12px', padding: '6px 14px' }} onClick={handleVerifyIntegrity} disabled={integrity?.state === 'loading'}>
                    <ShieldCheck size={14} />
                    <span>Re-verify signature</span>
                  </button>
                )}
              </div>

              {/* Evidence (GET /evidence, verify on demand) */}
              <div className="panel">
                <div className="panel-header">
                  <span className="panel-title">
                    <FileCheck size={16} color="var(--brand-orange)" />
                    Evidence{evidence.state === 'ok' ? ` (${evidence.data.length})` : ''}
                  </span>
                </div>
                {evidence.state !== 'ok' ? (
                  <LoadNote load={evidence} what="evidence" />
                ) : evidence.data.length === 0 ? (
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>No evidence uploaded.</p>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {evidence.data.map((ev) => {
                      const check = evidenceChecks[ev.id]
                      return (
                        <div key={ev.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '10px', padding: '10px 14px', background: '#F8FAFC', border: '1px solid #E2E8F0', borderRadius: '8px', fontSize: '12px' }}>
                          <div style={{ minWidth: 0 }}>
                            <div style={{ fontWeight: 700, color: '#0F172A' }}>{ev.displayName ?? ev.id}</div>
                            <div style={{ color: 'var(--text-muted)', fontSize: '11px' }}>
                              {ev.mimeType ?? NONE} • {ev.sizeBytes !== null ? `${ev.sizeBytes.toLocaleString()} bytes` : NONE} • {formatDateTime(ev.createdAt)}
                            </div>
                            <div className="mono-tag" style={{ fontSize: '10px', marginTop: '2px' }}>
                              SHA-256: {ev.sha256 ? `${ev.sha256.slice(0, 20)}…` : NONE}
                            </div>
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexShrink: 0 }}>
                            {check?.state === 'ok' && check.data && (
                              <span className="badge" style={statusColors(check.data.status === 'VALID')} title={check.data.reason ?? undefined}>
                                {check.data.status}
                              </span>
                            )}
                            {check?.state === 'ok' && !check.data && <span style={{ color: '#B91C1C' }}>Unexpected response</span>}
                            {check?.state === 'error' && <span style={{ color: '#B91C1C' }}>{check.error}</span>}
                            <button className="btn btn-ghost" style={{ fontSize: '11px', padding: '4px 10px' }} onClick={() => handleVerifyEvidence(ev.id)} disabled={check?.state === 'loading'}>
                              {check?.state === 'loading' ? <Loader2 size={12} className="spin" /> : <ShieldCheck size={12} />}
                              <span>Verify hash</span>
                            </button>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>

              {/* Payout (GET /payout) */}
              <div className="panel">
                <div className="panel-header">
                  <span className="panel-title">
                    <CreditCard size={16} />
                    Payout (simulated)
                  </span>
                  {payoutView?.payout && <span className="mono-tag">{payoutView.payout.id}</span>}
                </div>
                {payout.state !== 'ok' ? (
                  <LoadNote load={payout} what="payout" />
                ) : !payoutView?.payout ? (
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>No payout recorded.</p>
                ) : (
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '12px' }}>
                    <Field label="Amount">{formatZAR(payoutView.payout.amountCents)}</Field>
                    <Field label="Status">{payoutView.payout.status ?? NONE}</Field>
                    <Field label="To account">{payoutView.payout.destinationLast4 ? `•••• ${payoutView.payout.destinationLast4}` : NONE}</Field>
                    <Field label="Initiated">{formatDateTime(payoutView.payout.initiatedAt)}</Field>
                  </div>
                )}
              </div>
            </>
          )}
        </div>

        {/* Action bar: only ASSESSOR / MANAGER can act; INSURER_ADMIN and SUPERADMIN are read-only. */}
        <div className="drawer-footer">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-dim)' }}>Your role:</span>
            <span className="mono-tag">{role}</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
            {!canAct ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--text-dim)' }}>
                <Lock size={14} />
                <span>Read-only for {role}</span>
              </div>
            ) : !claim ? null : (
              <>
                {stage === 'Submitted' && (
                  <button className="btn btn-primary" onClick={() => runAction(() => ApiService.executeTransition(claimId, 'verify'))} disabled={busy}>
                    <span>Verify intake</span>
                    <ArrowRight size={14} />
                  </button>
                )}

                {stage === 'Verified' && (
                  <button className="btn btn-quantum" onClick={() => runAction(() => ApiService.executeTransition(claimId, 'screen'))} disabled={busy}>
                    <Cpu size={14} />
                    <span>Move to screening</span>
                  </button>
                )}

                {(stage === 'Screening' || stage === 'Review') && (
                  <button className="btn btn-ghost" onClick={() => setShowInfoModal(true)} disabled={busy}>
                    <MessageSquare size={14} />
                    <span>Request info</span>
                  </button>
                )}

                {stage === 'Screening' && (
                  <button className="btn btn-primary" onClick={() => runAction(() => ApiService.executeTransition(claimId, 'review'))} disabled={busy}>
                    <span>Submit for review</span>
                    <ArrowRight size={14} />
                  </button>
                )}

                {stage === 'Review' &&
                  (isManager ? (
                    <button className="btn btn-pqc" onClick={() => setShowDecisionModal(true)} disabled={busy}>
                      <KeyRound size={14} />
                      <span>Decide</span>
                    </button>
                  ) : (
                    <span style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--text-dim)' }}>
                      <Lock size={14} /> Decision requires MANAGER
                    </span>
                  ))}

                {stage === 'Appeal' &&
                  (isManager ? (
                    <button className="btn btn-primary" onClick={() => runAction(() => ApiService.executeTransition(claimId, 'review'))} disabled={busy}>
                      <RotateCcw size={14} />
                      <span>Re-review appeal</span>
                    </button>
                  ) : (
                    <span style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--text-dim)' }}>
                      <Lock size={14} /> Re-opening an appeal requires MANAGER
                    </span>
                  ))}

                {stage === 'Decision' && claim.status === 'Approved' && !alreadyPaid &&
                  (isManager ? (
                    <button className="btn btn-primary" style={{ background: 'linear-gradient(135deg, #059669, #10B981)' }} onClick={handlePay} disabled={busy || payout.state !== 'ok'}>
                      <CreditCard size={14} />
                      <span>Pay (simulated)</span>
                    </button>
                  ) : (
                    <span style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--text-dim)' }}>
                      <Lock size={14} /> Payout requires MANAGER
                    </span>
                  ))}

                {busy && <Loader2 size={16} className="spin" />}
              </>
            )}

            {stage === 'Paid' && (
              <span className="badge badge-paid" style={{ padding: '8px 16px', fontSize: '13px' }}>
                <CheckCircle2 size={14} />
                Paid
              </span>
            )}
          </div>
        </div>

        {/* Request-info modal */}
        {showInfoModal && (
          <div style={modalBackdrop}>
            <form onSubmit={handleRequestInfo} style={modalCard}>
              <h3 style={{ fontSize: '18px', fontWeight: 800, marginBottom: '6px', color: '#0F172A' }}>Request information</h3>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '16px' }}>
                The customer sees this message and the claim moves to Info Needed.
              </p>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px', color: '#0F172A' }} htmlFor="info-message">
                What is needed?
              </label>
              <textarea
                id="info-message"
                value={infoMessage}
                onChange={(e) => setInfoMessage(e.target.value)}
                minLength={2}
                maxLength={2000}
                required
                style={textarea}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '16px' }}>
                <button type="button" className="btn btn-ghost" onClick={() => setShowInfoModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={busy || infoMessage.trim().length < 2}>
                  <span>Send request</span>
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Decision modal (MANAGER) */}
        {showDecisionModal && claim && (
          <div style={modalBackdrop}>
            <form onSubmit={handleDecisionSubmit} style={modalCard}>
              <h3 style={{ fontSize: '18px', fontWeight: 800, marginBottom: '6px', color: '#0F172A' }}>Record decision</h3>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '20px' }}>
                The server records an insert-only decision and signs it; if signing is unavailable nothing is recorded.
              </p>

              <div style={{ marginBottom: '16px', display: 'flex', gap: '10px' }}>
                <button type="button" className={`btn ${decisionOutcome === 'Approved' ? 'btn-primary' : 'btn-ghost'}`} style={{ flex: 1, justifyContent: 'center' }} onClick={() => setDecisionOutcome('Approved')}>
                  Approve
                </button>
                <button type="button" className={`btn ${decisionOutcome === 'Rejected' ? 'btn-danger' : 'btn-ghost'}`} style={{ flex: 1, justifyContent: 'center' }} onClick={() => setDecisionOutcome('Rejected')}>
                  Reject
                </button>
              </div>

              {decisionOutcome === 'Approved' && (
                <div style={{ marginBottom: '16px' }}>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px', color: '#0F172A' }} htmlFor="approved-amount">
                    Approved amount (ZAR, optional)
                  </label>
                  <input
                    id="approved-amount"
                    type="number"
                    min="0.01"
                    step="0.01"
                    max={claim.claimedAmountCents !== null ? claim.claimedAmountCents / 100 : undefined}
                    value={approvedAmountRands}
                    onChange={(e) => setApprovedAmountRands(e.target.value)}
                    placeholder="Leave empty to approve the claimed amount"
                    className="search-input"
                    style={{ width: '100%', background: '#F8FAFC', border: '1px solid #CBD5E1', color: '#0F172A' }}
                  />
                  <span style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px', display: 'block' }}>
                    Claimed: {formatZAR(claim.claimedAmountCents)} (the server refuses more than this)
                  </span>
                </div>
              )}

              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px', color: '#0F172A' }} htmlFor="decision-reason">
                Reason
              </label>
              <textarea id="decision-reason" value={decisionReason} onChange={(e) => setDecisionReason(e.target.value)} maxLength={2000} required style={textarea} />

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '20px' }}>
                <button type="button" className="btn btn-ghost" onClick={() => setShowDecisionModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-pqc" disabled={busy || !decisionReason.trim()}>
                  <KeyRound size={14} />
                  <span>Record decision</span>
                </button>
              </div>
            </form>
          </div>
        )}
      </div>
    </div>
  )
}

const modalBackdrop: React.CSSProperties = {
  position: 'fixed',
  inset: 0,
  background: 'rgba(15, 23, 42, 0.6)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  zIndex: 200,
  padding: '16px',
}

const modalCard: React.CSSProperties = {
  background: '#FFFFFF',
  border: '1px solid var(--border-color)',
  borderRadius: 'var(--radius-lg)',
  padding: '28px',
  width: '480px',
  maxWidth: '100%',
  boxShadow: '0 20px 50px rgba(15, 23, 42, 0.15)',
}

const textarea: React.CSSProperties = {
  width: '100%',
  background: '#F8FAFC',
  border: '1px solid #CBD5E1',
  borderRadius: 'var(--radius-sm)',
  padding: '10px',
  color: '#0F172A',
  fontSize: '13px',
  minHeight: '90px',
  outline: 'none',
}
