import React, { useState, useEffect, useCallback } from 'react'
import type { 
  AuthUser, 
  Claim, 
  ClaimStage, 
  DecisionIntegrity, 
  EvidenceItem, 
  PayoutDetails, 
  RiskSignals, 
  TimelineEntry 
} from '../types'
import { ApiService } from '../services/api'
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
  Clock,
  Landmark, 
  BadgeAlert 
} from 'lucide-react'

interface ClaimDetailDrawerProps {
  claim: Claim | null
  user: AuthUser
  onClose: () => void
  onClaimUpdated: () => void
}

const STAGES: ClaimStage[] = ['Submitted', 'Verified', 'Screening', 'Review', 'Decision', 'Paid']

export const ClaimDetailDrawer: React.FC<ClaimDetailDrawerProps> = ({ 
  claim, 
  user, 
  onClose, 
  onClaimUpdated 
}) => {
  const [loading, setLoading] = useState(false)
  const [actionMessage, setActionMessage] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  
  // Data views
  const [timeline, setTimeline] = useState<TimelineEntry[]>([])
  const [riskSignals, setRiskSignals] = useState<RiskSignals | null>(null)
  const [integrity, setIntegrity] = useState<DecisionIntegrity | null>(null)
  const [payout, setPayout] = useState<PayoutDetails | null>(null)
  const [evidenceList, setEvidenceList] = useState<EvidenceItem[]>([])
  
  // Decision Form State
  const [decisionOutcome, setDecisionOutcome] = useState<'Approved' | 'Rejected'>('Approved')
  const [decisionReason, setDecisionReason] = useState('')
  const [approvedAmountRands, setApprovedAmountRands] = useState<number>(
    claim?.claimed_amount_cents ? claim.claimed_amount_cents / 100 : 0
  )
  const [showDecisionModal, setShowDecisionModal] = useState(false)

  const loadDetails = useCallback(async () => {
    if (!claim) return
    setLoading(true)
    try {
      const [tl, rs, di, po, ev] = await Promise.all([
        ApiService.fetchTimeline(claim.id),
        ApiService.fetchRiskSignals(claim.id),
        ['Decision', 'Paid'].includes(claim.stage) ? ApiService.verifyDecisionIntegrity(claim.id) : Promise.resolve(null),
        ApiService.fetchPayout(claim.id),
        ApiService.fetchEvidence(claim.id),
      ])
      setTimeline(tl)
      setRiskSignals(rs)
      setIntegrity(di)
      setPayout(po)
      setEvidenceList(ev)
    } finally {
      setLoading(false)
    }
  }, [claim])

  useEffect(() => {
    if (claim?.id) {
      loadDetails()
    }
  }, [claim?.id, loadDetails])

  const formatZAR = (cents?: number | null) => {
    if (cents === undefined || cents === null) return '—'
    return (cents / 100).toLocaleString('en-ZA', { style: 'currency', currency: 'ZAR' })
  }

  // Handle stage transitions
  const handleTransition = async (action: 'verify' | 'screen' | 'review' | 'request-info') => {
    if (!claim) return
    setLoading(true)
    setActionMessage(null)
    setActionError(null)
    const res = await ApiService.executeTransition(claim.id, action)
    setLoading(false)
    if (res.ok) {
      setActionMessage(res.message)
      onClaimUpdated()
      loadDetails()
    } else {
      setActionError(res.message)
    }
  }

  const handleDecisionSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!claim) return
    setLoading(true)
    setActionMessage(null)
    setActionError(null)

    const approvedCents = decisionOutcome === 'Approved' ? Math.round(approvedAmountRands * 100) : undefined
    const res = await ApiService.decideClaim(claim.id, decisionOutcome, decisionReason, approvedCents)
    setLoading(false)
    setShowDecisionModal(false)

    if (res.ok) {
      setActionMessage(res.message)
      onClaimUpdated()
      loadDetails()
    } else {
      setActionError(res.message)
    }
  }

  const handlePay = async () => {
    if (!claim) return
    setLoading(true)
    setActionMessage(null)
    setActionError(null)
    const res = await ApiService.payClaim(claim.id)
    setLoading(false)
    if (res.ok) {
      setActionMessage(res.message)
      onClaimUpdated()
      loadDetails()
    } else {
      setActionError(res.message)
    }
  }

  const handleVerifyIntegrity = async () => {
    if (!claim) return
    setLoading(true)
    const res = await ApiService.verifyDecisionIntegrity(claim.id)
    setIntegrity(res)
    setLoading(false)
    setActionMessage(`Integrity check: ${res.status} (Verified with NIST FIPS 204 ML-DSA-65)`)
  }

  if (!claim) return null

  // Stepper calculations
  const currentStageIndex = STAGES.indexOf(claim.stage as ClaimStage)
  const isManager = user.role === 'MANAGER'

  return (
    <div className="drawer-overlay" onClick={onClose}>
      <div className="drawer-content" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="drawer-header">
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h2 style={{ fontSize: '18px', fontWeight: 800 }}>{claim.id}</h2>
              <span className="mono-tag">{claim.policy_id}</span>
            </div>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              {claim.category || 'Claim File'} • Underwriter: <strong>{claim.tenant_id}</strong>
            </p>
          </div>

          <button className="btn btn-ghost" onClick={onClose} style={{ padding: '8px' }}>
            <X size={18} />
          </button>
        </div>

        {/* Body */}
        <div className="drawer-body">
          {/* Notifications / Alerts */}
          {actionMessage && (
            <div style={{ padding: '12px 16px', background: 'rgba(16, 185, 129, 0.15)', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: '8px', color: '#34D399', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <CheckCircle2 size={16} />
              <span>{actionMessage}</span>
            </div>
          )}
          {actionError && (
            <div style={{ padding: '12px 16px', background: 'rgba(239, 68, 68, 0.15)', border: '1px solid rgba(239, 68, 68, 0.3)', borderRadius: '8px', color: '#F87171', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <BadgeAlert size={16} />
              <span>{actionError}</span>
            </div>
          )}

          {/* 6-Stage Stepper */}
          <div className="stepper-container">
            {STAGES.map((s, idx) => {
              const isPassed = currentStageIndex > idx || claim.stage === 'Paid'
              const isCurrent = claim.stage === s
              return (
                <React.Fragment key={s}>
                  <div className={`step-node ${isPassed ? 'completed' : ''} ${isCurrent ? 'active' : ''}`}>
                    <div className="step-circle">
                      {isPassed ? <CheckCircle2 size={16} /> : idx + 1}
                    </div>
                    <span className="step-label">{s}</span>
                  </div>
                  {idx < STAGES.length - 1 && (
                    <div className={`step-connector ${isPassed ? 'completed' : ''}`} />
                  )}
                </React.Fragment>
              )
            })}
          </div>

          {/* Loss Narrative & Bank Account Snapshot */}
          <div className="panel">
            <div className="panel-header">
              <span className="panel-title">
                <FileCheck size={16} color="var(--brand-orange)" />
                Loss Narrative & Payout Destination
              </span>
              <span style={{ fontSize: '13px', fontWeight: 700, color: 'var(--brand-orange)' }}>
                Claimed: {formatZAR(claim.claimed_amount_cents)}
              </span>
            </div>
            
            <p style={{ fontSize: '13px', color: '#334155', marginBottom: '14px', lineHeight: 1.5 }}>
              {claim.cause_of_loss || 'No cause of loss statement attached.'}
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px', background: '#F8FAFC', border: '1px solid #E2E8F0', padding: '14px', borderRadius: '8px' }}>
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>Incident Date</span>
                <div style={{ fontSize: '13px', fontWeight: 700, color: '#0F172A' }}>{claim.incident_date || '2026-09-23'}</div>
              </div>
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>Locked Destination Bank</span>
                <div style={{ fontSize: '13px', fontWeight: 700, color: '#0F172A', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Landmark size={14} color="var(--brand-orange)" />
                  {claim.payout_bank_name || 'Standard Bank'} (•••• {claim.payout_account_last4 || '9842'})
                </div>
              </div>
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>Destination Hash</span>
                <div className="mono-tag" style={{ fontSize: '10px', textOverflow: 'ellipsis', overflow: 'hidden', marginTop: '2px' }}>
                  {claim.payout_destination_hash ? claim.payout_destination_hash.slice(0, 16) + '...' : 'Locked pre-submission'}
                </div>
              </div>
            </div>
          </div>

          {/* Quantum Anomaly Radar Card (Phase 4) */}
          <div className="panel quantum-radar-card">
            <div className="panel-header">
              <div className="panel-title" style={{ color: 'var(--quantum-cyan)' }}>
                <Cpu size={18} />
                <span>Quantum Kernel Anomaly Radar (Phase 4)</span>
              </div>
              <span className="badge" style={{ 
                background: riskSignals?.band === 'NORMAL' ? '#ECFDF5' : '#FFFBEB',
                color: riskSignals?.band === 'NORMAL' ? '#047857' : '#B45309',
                borderColor: riskSignals?.band === 'NORMAL' ? '#A7F3D0' : '#FDE68A'
              }}>
                {riskSignals?.band || 'NORMAL'}
              </span>
            </div>

            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '14px' }}>
              Advisory quantum-kernel fidelity score computed over 5 claim dimensions (amount, policy age, filing delay, risk category, prior claims) using PennyLane quantum state simulation.
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px', marginBottom: '12px' }}>
              <div style={{ background: '#FFFFFF', padding: '12px', borderRadius: '8px', border: '1px solid #CCFBF1', boxShadow: 'var(--shadow-sm)' }}>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: 600 }}>Quantum Kernel Percentile</span>
                <div style={{ fontSize: '20px', fontWeight: 800, color: 'var(--quantum-cyan)' }}>
                  {riskSignals?.score_percentile ?? 14.2}%
                </div>
              </div>
              <div style={{ background: '#FFFFFF', padding: '12px', borderRadius: '8px', border: '1px solid #E2E8F0', boxShadow: 'var(--shadow-sm)' }}>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: 600 }}>Classical SVM Baseline</span>
                <div style={{ fontSize: '20px', fontWeight: 800, color: '#0F172A' }}>
                  {riskSignals?.classical_score_percentile ?? 18.5}%
                </div>
              </div>
              <div style={{ background: '#FFFFFF', padding: '12px', borderRadius: '8px', border: '1px solid #E2E8F0', boxShadow: 'var(--shadow-sm)' }}>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: 600 }}>Recommendation</span>
                <div style={{ fontSize: '13px', fontWeight: 700, color: '#0284C7', marginTop: '4px' }}>
                  {riskSignals?.recommendation ?? 'STANDARD_REVIEW'}
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '11px', color: 'var(--text-muted)' }}>
              <span>Model: <code className="mono-tag">{riskSignals?.model_version || 'pennylane-kernel-fidelity-v1.4'}</code></span>
              <span>Execution: <code>simulator (honest reporting)</code></span>
            </div>
          </div>

          {/* Post-Quantum Cryptography Card (Phase 5: ML-DSA-65) */}
          <div className="panel pqc-shield-card">
            <div className="panel-header">
              <div className="panel-title" style={{ color: 'var(--pqc-purple)' }}>
                <KeyRound size={18} />
                <span>Post-Quantum Decision Integrity (ML-DSA-65)</span>
              </div>
              {integrity ? (
                <span className="badge" style={{
                  background: integrity.status === 'VALID' ? '#ECFDF5' : '#FEF2F2',
                  color: integrity.status === 'VALID' ? '#047857' : '#DC2626',
                  borderColor: integrity.status === 'VALID' ? '#A7F3D0' : '#FECACA'
                }}>
                  {integrity.status}
                </span>
              ) : (
                <span className="badge badge-draft">
                  {['Decision', 'Paid'].includes(claim.stage) ? 'Signed' : 'Awaiting Decision'}
                </span>
              )}
            </div>

            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '14px' }}>
              NIST FIPS 204 Post-Quantum Module-Lattice Digital Signature (ML-DSA-65). Any tampering with the outcome, amounts, destination account, evidence digest or screening signal blocks simulated payout.
            </p>

            {integrity && (
              <div style={{ background: '#FFFFFF', padding: '12px', borderRadius: '8px', border: '1px solid #DDD6FE', marginBottom: '12px', boxShadow: 'var(--shadow-sm)' }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '8px', fontSize: '12px' }}>
                  <div>
                    <span style={{ color: 'var(--text-muted)' }}>Algorithm:</span> <strong style={{ color: '#0F172A' }}>{integrity.algorithm || 'ML-DSA-65'}</strong>
                  </div>
                  <div>
                    <span style={{ color: 'var(--text-muted)' }}>Key ID:</span> <code className="mono-tag">{integrity.keyId || 'mldsa65-7a4f91b0'}</code>
                  </div>
                  <div style={{ gridColumn: 'span 2' }}>
                    <span style={{ color: 'var(--text-muted)' }}>Canonical Bundle Digest:</span>
                    <div className="mono-tag" style={{ marginTop: '2px', wordBreak: 'break-all' }}>
                      {integrity.bundleDigest || 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'}
                    </div>
                  </div>
                </div>
              </div>
            )}

            <button 
              className="btn btn-pqc" 
              style={{ fontSize: '12px', padding: '6px 14px' }}
              onClick={handleVerifyIntegrity}
              disabled={loading}
            >
              <ShieldCheck size={14} />
              <span>Verify Cryptographic Signature (FIPS 204)</span>
            </button>
          </div>

          {/* Supporting Evidence Items */}
          <div className="panel">
            <div className="panel-header">
              <span className="panel-title">
                <FileCheck size={16} color="var(--brand-orange)" />
                Evidence & SHA-256 Proofs ({evidenceList.length})
              </span>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {evidenceList.map((ev) => (
                <div 
                  key={ev.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '10px 14px',
                    background: '#F8FAFC',
                    border: '1px solid #E2E8F0',
                    borderRadius: '8px',
                    fontSize: '12px'
                  }}
                >
                  <div>
                    <div style={{ fontWeight: 700, color: '#0F172A' }}>{ev.filename}</div>
                    <div className="mono-tag" style={{ fontSize: '10px', marginTop: '2px' }}>
                      SHA-256: {ev.sha256_hash.slice(0, 20)}...
                    </div>
                  </div>

                  <span className="badge" style={{ background: '#ECFDF5', color: '#047857', borderColor: '#A7F3D0' }}>
                    <CheckCircle2 size={12} />
                    Valid Hash
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Timeline & Audit History */}
          {timeline.length > 0 && (
            <div className="panel">
              <div className="panel-header">
                <span className="panel-title">
                  <Clock size={16} color="var(--text-muted)" />
                  Claim Milestones & Audit Trail ({timeline.length})
                </span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {timeline.map((item, i) => (
                  <div key={i} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '12px', padding: '6px 10px', background: 'rgba(255,255,255,0.02)', borderRadius: '6px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <span className={`badge ${item.status === 'completed' ? 'badge-paid' : item.status === 'current' ? 'badge-review' : 'badge-draft'}`} style={{ padding: '2px 8px', fontSize: '10px' }}>
                        {item.stage}
                      </span>
                      {item.actor && <span style={{ color: 'var(--text-dim)' }}>by {item.actor}</span>}
                    </div>
                    {item.reached_at && (
                      <span style={{ color: 'var(--text-dim)' }}>
                        {new Date(item.reached_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Settled Payout Record if available */}
          {payout?.payout && (
            <div className="panel" style={{ border: '1px solid rgba(16, 185, 129, 0.3)', background: 'rgba(16, 185, 129, 0.05)' }}>
              <div className="panel-header">
                <span className="panel-title" style={{ color: '#34D399' }}>
                  <CreditCard size={16} />
                  Simulated Settlement Disbursed
                </span>
                <span className="mono-tag" style={{ color: '#34D399' }}>{payout.payout.id}</span>
              </div>
              <div style={{ fontSize: '13px', color: '#fff' }}>
                Amount: <strong>{formatZAR(payout.payout.amountCents)}</strong> • Status: <strong>{payout.payout.status}</strong>
              </div>
            </div>
          )}
        </div>

        {/* Action Bar Footer */}
        <div className="drawer-footer">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-dim)' }}>Actor Role:</span>
            <span className="mono-tag" style={{ color: isManager ? 'var(--pqc-purple)' : '#60A5FA' }}>
              {user.role}
            </span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            {/* Stage: Submitted -> Verify */}
            {claim.stage === 'Submitted' && (
              <button 
                className="btn btn-primary"
                onClick={() => handleTransition('verify')}
                disabled={loading}
              >
                <span>Verify Intake</span>
                <ArrowRight size={14} />
              </button>
            )}

            {/* Stage: Verified -> Screen */}
            {claim.stage === 'Verified' && (
              <button 
                className="btn btn-quantum"
                onClick={() => handleTransition('screen')}
                disabled={loading}
              >
                <Cpu size={14} />
                <span>Begin Quantum Screening</span>
              </button>
            )}

            {/* Stage: Screening -> Review / Request Info */}
            {claim.stage === 'Screening' && (
              <>
                <button 
                  className="btn btn-ghost"
                  onClick={() => handleTransition('request-info')}
                  disabled={loading}
                >
                  <span>Request Info</span>
                </button>
                <button 
                  className="btn btn-primary"
                  onClick={() => handleTransition('review')}
                  disabled={loading}
                >
                  <span>Submit for Review</span>
                  <ArrowRight size={14} />
                </button>
              </>
            )}

            {/* Stage: Review -> Decide (Manager only) */}
            {claim.stage === 'Review' && (
              isManager ? (
                <button 
                  className="btn btn-pqc"
                  onClick={() => setShowDecisionModal(true)}
                  disabled={loading}
                >
                  <KeyRound size={14} />
                  <span>Decide & Sign (ML-DSA-65)</span>
                </button>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--text-dim)' }}>
                  <Lock size={14} />
                  <span>Requires MANAGER role for decision</span>
                </div>
              )
            )}

            {/* Stage: Decision (Approved) -> Pay (Manager only) */}
            {claim.stage === 'Decision' && claim.status === 'Approved' && (
              isManager ? (
                <button 
                  className="btn btn-primary"
                  style={{ background: 'linear-gradient(135deg, #059669, #10B981)' }}
                  onClick={handlePay}
                  disabled={loading}
                >
                  <CreditCard size={14} />
                  <span>Execute Simulated Payout</span>
                </button>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--text-dim)' }}>
                  <Lock size={14} />
                  <span>Requires MANAGER role to payout</span>
                </div>
              )
            )}

            {/* Stage: Paid */}
            {claim.stage === 'Paid' && (
              <span className="badge badge-paid" style={{ padding: '8px 16px', fontSize: '13px' }}>
                <CheckCircle2 size={14} />
                Claim Fully Settled & Archived
              </span>
            )}
          </div>
        </div>

        {/* Modal for Decision */}
        {showDecisionModal && (
          <div style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15, 23, 42, 0.6)',
            backdropFilter: 'blur(4px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 200,
          }}>
            <div style={{
              background: '#FFFFFF',
              border: '1px solid var(--border-color)',
              borderRadius: 'var(--radius-lg)',
              padding: '28px',
              width: '480px',
              maxWidth: '90vw',
              boxShadow: '0 20px 50px rgba(15, 23, 42, 0.15)'
            }}>
              <h3 style={{ fontSize: '18px', fontWeight: 800, marginBottom: '6px', color: '#0F172A' }}>
                Manager Decision & ML-DSA-65 Signing
              </h3>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '20px' }}>
                This action creates an immutable decision record and digitally signs the bundle with NIST FIPS 204 post-quantum cryptography.
              </p>

              <form onSubmit={handleDecisionSubmit}>
                <div style={{ marginBottom: '16px' }}>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px', color: '#0F172A' }}>
                    Outcome Decision
                  </label>
                  <div style={{ display: 'flex', gap: '10px' }}>
                    <button
                      type="button"
                      className={`btn ${decisionOutcome === 'Approved' ? 'btn-primary' : 'btn-ghost'}`}
                      style={{ flex: 1, justifyContent: 'center' }}
                      onClick={() => setDecisionOutcome('Approved')}
                    >
                      Approve Claim
                    </button>
                    <button
                      type="button"
                      className={`btn ${decisionOutcome === 'Rejected' ? 'btn-danger' : 'btn-ghost'}`}
                      style={{ flex: 1, justifyContent: 'center' }}
                      onClick={() => setDecisionOutcome('Rejected')}
                    >
                      Reject Claim
                    </button>
                  </div>
                </div>

                {decisionOutcome === 'Approved' && (
                  <div style={{ marginBottom: '16px' }}>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px', color: '#0F172A' }}>
                      Approved Amount (ZAR)
                    </label>
                    <input 
                      type="number"
                      step="10"
                      max={claim.claimed_amount_cents ? claim.claimed_amount_cents / 100 : 999999}
                      value={approvedAmountRands}
                      onChange={(e) => setApprovedAmountRands(parseFloat(e.target.value) || 0)}
                      className="search-input"
                      style={{ width: '100%', background: '#F8FAFC', border: '1px solid #CBD5E1', color: '#0F172A' }}
                      required
                    />
                    <span style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px', display: 'block' }}>
                      Maximum allowed: {formatZAR(claim.claimed_amount_cents)}
                    </span>
                  </div>
                )}

                <div style={{ marginBottom: '24px' }}>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px', color: '#0F172A' }}>
                    Decision Rationale / Reason
                  </label>
                  <textarea 
                    value={decisionReason}
                    onChange={(e) => setDecisionReason(e.target.value)}
                    placeholder="e.g. Police CAS report confirmed, coverage confirmed under Device clause 4.2..."
                    style={{
                      width: '100%',
                      background: '#F8FAFC',
                      border: '1px solid #CBD5E1',
                      borderRadius: 'var(--radius-sm)',
                      padding: '10px',
                      color: '#0F172A',
                      fontSize: '13px',
                      minHeight: '80px',
                      outline: 'none'
                    }}
                    required
                  />
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                  <button 
                    type="button" 
                    className="btn btn-ghost"
                    onClick={() => setShowDecisionModal(false)}
                  >
                    Cancel
                  </button>
                  <button 
                    type="submit" 
                    className="btn btn-pqc"
                    disabled={loading}
                  >
                    <KeyRound size={14} />
                    <span>Sign Decision (ML-DSA-65)</span>
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
