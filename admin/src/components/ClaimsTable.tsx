import React, { useState } from 'react'
import type { Claim, ClaimStage } from '../types'
import { 
  Search, 
  Filter, 
  ChevronRight, 
  Cpu, 
  ShieldCheck, 
  AlertCircle,
  Clock,
  Landmark
} from 'lucide-react'

interface ClaimsTableProps {
  claims: Claim[]
  onSelectClaim: (claim: Claim) => void
  selectedClaimId?: string
}

export const ClaimsTable: React.FC<ClaimsTableProps> = ({ claims, onSelectClaim, selectedClaimId }) => {
  const [searchTerm, setSearchTerm] = useState('')
  const [stageFilter, setStageFilter] = useState<string>('ALL')

  const getStageBadgeClass = (stage: ClaimStage) => {
    switch (stage) {
      case 'Draft': return 'badge-draft'
      case 'Submitted': return 'badge-submitted'
      case 'Verified': return 'badge-verified'
      case 'Screening': return 'badge-screening'
      case 'Review': return 'badge-review'
      case 'Decision': return 'badge-decision'
      case 'Paid': return 'badge-paid'
      case 'Info Needed': return 'badge-info-needed'
      case 'Appeal': return 'badge-appeal'
      default: return 'badge-draft'
    }
  }

  const formatZAR = (cents?: number | null) => {
    if (cents === undefined || cents === null) return '—'
    return (cents / 100).toLocaleString('en-ZA', { style: 'currency', currency: 'ZAR' })
  }

  const filteredClaims = claims.filter(c => {
    const matchesSearch = 
      c.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      c.policy_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (c.category && c.category.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (c.cause_of_loss && c.cause_of_loss.toLowerCase().includes(searchTerm.toLowerCase()))

    const matchesStage = stageFilter === 'ALL' || c.stage === stageFilter
    return matchesSearch && matchesStage
  })

  return (
    <div className="content-card">
      <div className="card-header-actions">
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px', flexWrap: 'wrap' }}>
          <div style={{ position: 'relative' }}>
            <Search size={16} color="var(--text-dim)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
            <input 
              type="text" 
              placeholder="Search Claim ID, policy, loss..."
              className="search-input"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Filter size={15} color="var(--text-dim)" />
            <select
              value={stageFilter}
              onChange={(e) => setStageFilter(e.target.value)}
              style={{
                background: '#F8FAFC',
                border: '1px solid #CBD5E1',
                borderRadius: 'var(--radius-sm)',
                color: '#0F172A',
                padding: '8px 12px',
                fontSize: '13px',
                outline: 'none',
                cursor: 'pointer',
                fontWeight: 600
              }}
            >
              <option value="ALL" style={{ background: '#FFFFFF', color: '#0F172A' }}>All Stages</option>
              <option value="Submitted" style={{ background: '#FFFFFF', color: '#0F172A' }}>Submitted</option>
              <option value="Verified" style={{ background: '#FFFFFF', color: '#0F172A' }}>Verified</option>
              <option value="Screening" style={{ background: '#FFFFFF', color: '#0F172A' }}>Screening (Quantum)</option>
              <option value="Review" style={{ background: '#FFFFFF', color: '#0F172A' }}>Review</option>
              <option value="Decision" style={{ background: '#FFFFFF', color: '#0F172A' }}>Decision (ML-DSA)</option>
              <option value="Paid" style={{ background: '#FFFFFF', color: '#0F172A' }}>Paid (Simulated)</option>
              <option value="Info Needed" style={{ background: '#FFFFFF', color: '#0F172A' }}>Info Needed</option>
              <option value="Appeal" style={{ background: '#FFFFFF', color: '#0F172A' }}>Appeal</option>
            </select>
          </div>
        </div>

        <div style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
          Showing <strong>{filteredClaims.length}</strong> of {claims.length} claims
        </div>
      </div>

      <div style={{ overflowX: 'auto' }}>
        <table className="claims-table">
          <thead>
            <tr>
              <th>Claim Reference</th>
              <th>Category & Description</th>
              <th>Claimed Amount</th>
              <th>Payout Destination</th>
              <th>Stage & Security</th>
              <th>Date Filed</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {filteredClaims.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '48px 20px', color: 'var(--text-dim)' }}>
                  <AlertCircle size={28} style={{ margin: '0 auto 8px', display: 'block', opacity: 0.5 }} />
                  No claims found matching the filter criteria.
                </td>
              </tr>
            ) : (
              filteredClaims.map((claim) => (
                <tr 
                  key={claim.id} 
                  onClick={() => onSelectClaim(claim)}
                  style={{
                    backgroundColor: selectedClaimId === claim.id ? 'rgba(255, 85, 0, 0.08)' : undefined,
                    borderLeft: selectedClaimId === claim.id ? '3px solid var(--brand-orange)' : '3px solid transparent'
                  }}
                >
                  <td>
                    <div style={{ fontWeight: 700, color: '#0F172A', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      {claim.id}
                    </div>
                    <div className="mono-tag" style={{ marginTop: '4px', display: 'inline-block' }}>
                      {claim.policy_id}
                    </div>
                  </td>

                  <td style={{ maxWidth: '240px' }}>
                    <div style={{ fontWeight: 700, color: '#0F172A' }}>{claim.category || 'General Claim'}</div>
                    <div style={{ fontSize: '12px', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={claim.cause_of_loss}>
                      {claim.cause_of_loss || 'No loss narrative recorded'}
                    </div>
                  </td>

                  <td>
                    <div style={{ fontWeight: 800, fontSize: '14px', color: 'var(--brand-orange)' }}>
                      {formatZAR(claim.claimed_amount_cents)}
                    </div>
                  </td>

                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}>
                      <Landmark size={14} color="var(--text-muted)" />
                      <span>{claim.payout_bank_name || 'Standard Bank'}</span>
                    </div>
                    <div className="mono-tag" style={{ marginTop: '2px', display: 'inline-block' }}>
                      •••• {claim.payout_account_last4 || '9842'}
                    </div>
                  </td>

                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <span className={`badge ${getStageBadgeClass(claim.stage)}`}>
                        {claim.stage}
                      </span>
                      {claim.stage === 'Screening' && (
                        <span title="Quantum Screening Active">
                          <Cpu size={14} color="var(--quantum-cyan)" />
                        </span>
                      )}
                      {['Decision', 'Paid'].includes(claim.stage) && (
                        <span title="Signed with ML-DSA-65">
                          <ShieldCheck size={14} color="var(--pqc-purple)" />
                        </span>
                      )}
                    </div>
                  </td>

                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-dim)', fontSize: '12px' }}>
                      <Clock size={13} />
                      <span>{new Date(claim.created_at).toLocaleDateString()}</span>
                    </div>
                  </td>

                  <td>
                    <button 
                      className="btn btn-ghost" 
                      style={{ padding: '6px 12px', fontSize: '12px' }}
                      onClick={(e) => {
                        e.stopPropagation()
                        onSelectClaim(claim)
                      }}
                    >
                      <span>Review</span>
                      <ChevronRight size={14} />
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
