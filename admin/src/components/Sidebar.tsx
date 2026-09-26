import React from 'react'
import { TENANTS } from '../types'
import type { AuthUser } from '../types'
import { 
  ShieldCheck, 
  FileText, 
  Cpu, 
  Lock, 
  Activity, 
  CheckCircle2,
  Building2 
} from 'lucide-react'

interface SidebarProps {
  user: AuthUser
  activeTab: string
  setActiveTab: (tab: string) => void
  claimsCount: number
}

export const Sidebar: React.FC<SidebarProps> = ({ user, activeTab, setActiveTab, claimsCount }) => {
  const tenant = TENANTS[user.tenantId] || TENANTS.ins_discovery

  return (
    <aside className="sidebar">
      {/* Brand Header */}
      <div className="brand-header">
        <div className="brand-icon">
          <ShieldCheck size={24} />
        </div>
        <div>
          <div className="brand-name">Easy<span>Claim</span></div>
          <div className="brand-sub">Insurer Operations</div>
        </div>
      </div>

      {/* Tenant Pill */}
      <div className="tenant-pill">
        <div className="tenant-dot" style={{ backgroundColor: tenant.color, color: tenant.color }} />
        <div className="tenant-info">
          <div className="tenant-name" title={tenant.name}>{tenant.name}</div>
          <div className="tenant-role">
            <Building2 size={11} />
            <span>Tenant: {tenant.code}</span>
          </div>
        </div>
      </div>

      {/* Nav Menu */}
      <nav className="nav-menu">
        <div 
          className={`nav-item ${activeTab === 'claims' ? 'active' : ''}`}
          onClick={() => setActiveTab('claims')}
        >
          <FileText size={18} />
          <span style={{ flex: 1 }}>Claims Worklist</span>
          <span style={{ 
            fontSize: '11px', 
            background: 'rgba(255, 85, 0, 0.2)', 
            color: 'var(--brand-orange-light)', 
            padding: '2px 8px', 
            borderRadius: '999px',
            fontWeight: 700 
          }}>
            {claimsCount}
          </span>
        </div>

        <div 
          className={`nav-item ${activeTab === 'quantum' ? 'active' : ''}`}
          onClick={() => setActiveTab('quantum')}
        >
          <Cpu size={18} color="var(--quantum-cyan)" />
          <span style={{ flex: 1 }}>Quantum Screening</span>
          <span style={{ 
            fontSize: '10px', 
            background: 'rgba(6, 182, 212, 0.2)', 
            color: 'var(--quantum-cyan)', 
            padding: '2px 6px', 
            borderRadius: '999px',
            fontWeight: 700 
          }}>
            Advisory
          </span>
        </div>

        <div 
          className={`nav-item ${activeTab === 'pqc' ? 'active' : ''}`}
          onClick={() => setActiveTab('pqc')}
        >
          <Lock size={18} color="var(--pqc-purple)" />
          <span style={{ flex: 1 }}>ML-DSA-65 Integrity</span>
          <span style={{ 
            fontSize: '10px', 
            background: 'rgba(139, 92, 246, 0.2)', 
            color: 'var(--pqc-purple)', 
            padding: '2px 6px', 
            borderRadius: '999px',
            fontWeight: 700 
          }}>
            FIPS 204
          </span>
        </div>

        <div 
          className={`nav-item ${activeTab === 'audit' ? 'active' : ''}`}
          onClick={() => setActiveTab('audit')}
        >
          <Activity size={18} />
          <span>Audit & Ledger</span>
        </div>
      </nav>

      {/* Security Footprint Card */}
      <div style={{
        marginTop: 'auto',
        background: '#F8FAFC',
        border: '1px solid var(--border-color)',
        borderRadius: 'var(--radius-md)',
        padding: '14px',
        fontSize: '11px',
        color: 'var(--text-muted)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#059669', fontWeight: 700, marginBottom: '6px' }}>
          <CheckCircle2 size={13} />
          <span>Zero-Trust 6-Gate Architecture</span>
        </div>
        <p style={{ lineHeight: 1.4 }}>
          Tenant isolation, append-only SQLite triggers, and post-quantum signing active.
        </p>
      </div>
    </aside>
  )
}
