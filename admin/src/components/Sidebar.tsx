import React from 'react'
import type { Role, Session } from '../types'
import { ShieldCheck, FileText, Cpu, Lock, Activity, Building2 } from 'lucide-react'

export type TabId = 'claims' | 'quantum' | 'pqc' | 'audit'

/**
 * Which views a role can use, following the backend's RBAC:
 * - GET /claims answers 403 for SUPERADMIN (platform operator sees aggregates only).
 * - The audit log exists only as /tenant/audit (INSURER_ADMIN) and /admin/audit (SUPERADMIN).
 */
export function tabsFor(role: Role): TabId[] {
  switch (role) {
    case 'ASSESSOR':
    case 'MANAGER':
      return ['claims', 'quantum', 'pqc']
    case 'INSURER_ADMIN':
      return ['claims', 'quantum', 'pqc', 'audit']
    case 'SUPERADMIN':
      return ['pqc', 'quantum', 'audit']
    default:
      return []
  }
}

interface SidebarProps {
  session: Session
  tabs: TabId[]
  activeTab: TabId
  setActiveTab: (tab: TabId) => void
  /** null when the count is not known (not loaded, failed, or not visible to this role). */
  claimsCount: number | null
}

const LABELS: Record<TabId, { label: string; icon: React.ReactNode }> = {
  claims: { label: 'Claims Worklist', icon: <FileText size={18} /> },
  quantum: { label: 'Quantum Screening', icon: <Cpu size={18} color="var(--quantum-cyan)" /> },
  pqc: { label: 'Decision Integrity', icon: <Lock size={18} color="var(--pqc-purple)" /> },
  audit: { label: 'Audit Log', icon: <Activity size={18} /> },
}

export const Sidebar: React.FC<SidebarProps> = ({ session, tabs, activeTab, setActiveTab, claimsCount }) => {
  const { actor } = session

  return (
    <aside className="sidebar">
      <div className="brand-header">
        <div className="brand-icon">
          <ShieldCheck size={24} />
        </div>
        <div>
          <div className="brand-name">Easy<span>Claim</span></div>
          <div className="brand-sub">Insurer Operations</div>
        </div>
      </div>

      <div className="tenant-pill">
        <div className="tenant-dot" style={{ backgroundColor: 'var(--brand-orange)', color: 'var(--brand-orange)' }} />
        <div className="tenant-info">
          <div className="tenant-name" title={actor.tenantId ?? 'Platform'}>
            {actor.tenantId ?? 'Platform (no tenant)'}
          </div>
          <div className="tenant-role">
            <Building2 size={11} />
            <span>{actor.role}</span>
          </div>
        </div>
      </div>

      <nav className="nav-menu">
        {tabs.map((tab) => (
          <div
            key={tab}
            className={`nav-item ${activeTab === tab ? 'active' : ''}`}
            onClick={() => setActiveTab(tab)}
          >
            {LABELS[tab].icon}
            <span style={{ flex: 1 }}>{LABELS[tab].label}</span>
            {tab === 'claims' && claimsCount !== null && (
              <span
                style={{
                  fontSize: '11px',
                  background: 'rgba(255, 85, 0, 0.2)',
                  color: 'var(--brand-orange-light)',
                  padding: '2px 8px',
                  borderRadius: '999px',
                  fontWeight: 700,
                }}
              >
                {claimsCount}
              </span>
            )}
          </div>
        ))}
      </nav>
    </aside>
  )
}
