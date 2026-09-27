import React from 'react'
import type { ClaimSummary } from '../types'
import { FileCheck2, Hourglass, Gavel, Coins } from 'lucide-react'
import { formatZAR } from '../services/mappers'

interface StatsCardsProps {
  claims: ClaimSummary[]
}

const IN_PROGRESS = ['Submitted', 'Verified', 'Screening', 'Review']
const WAITING = ['Info Needed', 'Appeal']
const DECIDED = ['Decision', 'Paid']

/** Counts computed only from the claims the backend returned (GET /claims, max 50 most recent). */
export const StatsCards: React.FC<StatsCardsProps> = ({ claims }) => {
  const count = (stages: string[]) => claims.filter((c) => stages.includes(c.stage)).length
  const withAmount = claims.filter((c) => c.claimedAmountCents !== null)
  const totalClaimedCents = withAmount.reduce((acc, c) => acc + (c.claimedAmountCents ?? 0), 0)
  const scope = claims.length >= 50 ? 'Most recent 50 claims' : 'All claims returned'

  const cards: { title: string; value: string; note: string; icon: React.ReactNode }[] = [
    { title: 'Claims in worklist', value: String(claims.length), note: scope, icon: <FileCheck2 size={18} /> },
    { title: 'In progress', value: String(count(IN_PROGRESS)), note: 'Submitted → Review', icon: <Hourglass size={18} /> },
    {
      title: 'Decided',
      value: String(count(DECIDED)),
      note: `${count(WAITING)} waiting on info / appeal`,
      icon: <Gavel size={18} />,
    },
    {
      title: 'Total claimed (ZAR)',
      value: withAmount.length ? formatZAR(totalClaimedCents) : '—',
      note: `${claims.length - withAmount.length} without a claimed amount`,
      icon: <Coins size={18} />,
    },
  ]

  return (
    <div className="stats-grid">
      {cards.map((c) => (
        <div className="stat-card" key={c.title}>
          <div className="stat-card-header">
            <span className="stat-title">{c.title}</span>
            <div className="stat-icon" style={{ background: '#EFF6FF', color: '#2563EB', border: '1px solid #DBEAFE' }}>
              {c.icon}
            </div>
          </div>
          <div className="stat-value">{c.value}</div>
          <div className="stat-badge" style={{ background: '#F8FAFC', color: 'var(--text-muted)', border: '1px solid var(--border-color)' }}>
            <span>{c.note}</span>
          </div>
        </div>
      ))}
    </div>
  )
}
