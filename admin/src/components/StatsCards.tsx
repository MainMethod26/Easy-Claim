import React from 'react'
import type { Claim } from '../types'
import { 
  FileCheck2, 
  Cpu, 
  ShieldCheck, 
  Coins 
} from 'lucide-react'

interface StatsCardsProps {
  claims: Claim[]
}

export const StatsCards: React.FC<StatsCardsProps> = ({ claims }) => {
  const totalClaims = claims.length
  const pendingReview = claims.filter(c => ['Submitted', 'Verified', 'Screening', 'Review'].includes(c.stage)).length
  const approvedClaims = claims.filter(c => ['Decision', 'Paid'].includes(c.stage) && c.status === 'Approved').length
  
  // Calculate total claimed volume in ZAR
  const totalClaimedCents = claims.reduce((acc, c) => acc + (c.claimed_amount_cents || 0), 0)
  const formatZAR = (cents: number) => {
    const rands = (cents / 100).toLocaleString('en-ZA', { style: 'currency', currency: 'ZAR', maximumFractionDigits: 0 })
    return rands
  }

  return (
    <div className="stats-grid">
      {/* Total Active Claims */}
      <div className="stat-card">
        <div className="stat-card-header">
          <span className="stat-title">Tenant Claims Worklist</span>
          <div className="stat-icon" style={{ background: '#EFF6FF', color: '#2563EB', border: '1px solid #DBEAFE' }}>
            <FileCheck2 size={18} />
          </div>
        </div>
        <div className="stat-value">{totalClaims}</div>
        <div className="stat-badge" style={{ background: '#EFF6FF', color: '#2563EB', border: '1px solid #DBEAFE' }}>
          <span>{pendingReview} action items pending</span>
        </div>
      </div>

      {/* Quantum Anomaly Screening */}
      <div className="stat-card" style={{ borderLeft: '3px solid var(--quantum-cyan)' }}>
        <div className="stat-card-header">
          <span className="stat-title">Quantum Anomaly Radar</span>
          <div className="stat-icon" style={{ background: 'var(--quantum-bg)', color: 'var(--quantum-cyan)', border: '1px solid var(--quantum-border)' }}>
            <Cpu size={18} />
          </div>
        </div>
        <div className="stat-value" style={{ color: 'var(--quantum-cyan)' }}>Active</div>
        <div className="stat-badge" style={{ background: 'var(--quantum-bg)', color: 'var(--quantum-cyan)', border: '1px solid var(--quantum-border)' }}>
          <span>PennyLane Fidelity Kernel (Ph. 4)</span>
        </div>
      </div>

      {/* Post-Quantum Decision Signing */}
      <div className="stat-card" style={{ borderLeft: '3px solid var(--pqc-purple)' }}>
        <div className="stat-card-header">
          <span className="stat-title">Post-Quantum Integrity</span>
          <div className="stat-icon" style={{ background: 'var(--pqc-bg)', color: 'var(--pqc-purple)', border: '1px solid var(--pqc-border)' }}>
            <ShieldCheck size={18} />
          </div>
        </div>
        <div className="stat-value" style={{ color: 'var(--pqc-purple)' }}>100%</div>
        <div className="stat-badge" style={{ background: 'var(--pqc-bg)', color: 'var(--pqc-purple)', border: '1px solid var(--pqc-border)' }}>
          <span>NIST FIPS 204 (ML-DSA-65)</span>
        </div>
      </div>

      {/* Total Claim Exposure */}
      <div className="stat-card" style={{ borderLeft: '3px solid var(--brand-orange)' }}>
        <div className="stat-card-header">
          <span className="stat-title">Total Claim Value (ZAR)</span>
          <div className="stat-icon" style={{ background: 'var(--brand-orange-soft)', color: 'var(--brand-orange)', border: '1px solid var(--brand-orange-border)' }}>
            <Coins size={18} />
          </div>
        </div>
        <div className="stat-value" style={{ color: 'var(--brand-orange)' }}>
          {formatZAR(totalClaimedCents)}
        </div>
        <div className="stat-badge" style={{ background: '#ECFDF5', color: '#047857', border: '1px solid #A7F3D0' }}>
          <span>{approvedClaims} approved / settled</span>
        </div>
      </div>
    </div>
  )
}
