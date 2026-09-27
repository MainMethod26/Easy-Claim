import React, { useState } from 'react'
import type { ClaimSummary } from '../types'
import { Search, Filter, ChevronRight, AlertCircle, Clock, Loader2 } from 'lucide-react'
import { formatDate, formatZAR, NONE } from '../services/mappers'

interface ClaimsTableProps {
  claims: ClaimSummary[]
  loading: boolean
  onSelectClaim: (claim: ClaimSummary) => void
  selectedClaimId?: string
}

export function stageBadgeClass(stage: string): string {
  switch (stage) {
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

const FILTER_STAGES = ['Submitted', 'Verified', 'Screening', 'Review', 'Decision', 'Paid', 'Info Needed', 'Appeal', 'Withdrawn', 'Expired']

/**
 * The claim list shows only what GET /claims returns. That endpoint carries no payout destination,
 * cause of loss or incident date; those are shown in the claim drawer from GET /claims/:id.
 */
export const ClaimsTable: React.FC<ClaimsTableProps> = ({ claims, loading, onSelectClaim, selectedClaimId }) => {
  const [searchTerm, setSearchTerm] = useState('')
  const [stageFilter, setStageFilter] = useState<string>('ALL')

  const term = searchTerm.toLowerCase()
  const filteredClaims = claims.filter((c) => {
    const matchesSearch =
      c.id.toLowerCase().includes(term) ||
      c.policyId.toLowerCase().includes(term) ||
      (c.category !== null && c.category.toLowerCase().includes(term))
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
              placeholder="Search claim ID, policy, category..."
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
                fontWeight: 600,
              }}
            >
              <option value="ALL">All Stages</option>
              {FILTER_STAGES.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
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
              <th>Category</th>
              <th>Claimed Amount</th>
              <th>Stage</th>
              <th>Status</th>
              <th>Date Filed</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '48px 20px', color: 'var(--text-dim)' }}>
                  <Loader2 size={20} className="spin" style={{ margin: '0 auto 8px', display: 'block' }} />
                  Loading claims…
                </td>
              </tr>
            ) : filteredClaims.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '48px 20px', color: 'var(--text-dim)' }}>
                  <AlertCircle size={28} style={{ margin: '0 auto 8px', display: 'block', opacity: 0.5 }} />
                  {claims.length === 0 ? 'No claims for this tenant.' : 'No claims match the filter.'}
                </td>
              </tr>
            ) : (
              filteredClaims.map((claim) => (
                <tr
                  key={claim.id}
                  onClick={() => onSelectClaim(claim)}
                  style={{
                    backgroundColor: selectedClaimId === claim.id ? 'rgba(255, 85, 0, 0.08)' : undefined,
                    borderLeft: selectedClaimId === claim.id ? '3px solid var(--brand-orange)' : '3px solid transparent',
                  }}
                >
                  <td>
                    <div style={{ fontWeight: 700, color: '#0F172A' }}>{claim.id}</div>
                    <div className="mono-tag" style={{ marginTop: '4px', display: 'inline-block' }}>
                      {claim.policyId || NONE}
                    </div>
                  </td>
                  <td style={{ fontWeight: 700, color: '#0F172A' }}>{claim.category ?? NONE}</td>
                  <td>
                    <div style={{ fontWeight: 800, fontSize: '14px', color: 'var(--brand-orange)' }}>
                      {formatZAR(claim.claimedAmountCents)}
                    </div>
                  </td>
                  <td>
                    <span className={`badge ${stageBadgeClass(claim.stage)}`}>{claim.stage}</span>
                  </td>
                  <td style={{ fontSize: '12px' }}>{claim.status ?? NONE}</td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-dim)', fontSize: '12px' }}>
                      <Clock size={13} />
                      <span>{formatDate(claim.createdAt)}</span>
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
                      <span>Open</span>
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
