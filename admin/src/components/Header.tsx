import React from 'react'
import { TENANTS } from '../types'
import type { AuthUser } from '../types'
import { ApiService } from '../services/api'
import { UserCheck, RefreshCw, LogOut, Cpu, KeyRound } from 'lucide-react'

interface HeaderProps {
  user: AuthUser
  onUserChange: (user: AuthUser) => void
  onRefresh: () => void
  isRefreshing: boolean
}

export const Header: React.FC<HeaderProps> = ({ user, onUserChange, onRefresh, isRefreshing }) => {
  const tenant = TENANTS[user.tenantId] || TENANTS.ins_discovery
  const demoActors = ApiService.getDemoActors()

  const handleActorSwitch = async (e: React.ChangeEvent<HTMLSelectElement>) => {
    const selected = demoActors.find(a => a.id === e.target.value)
    if (selected) {
      try {
        const newUser = await ApiService.login(selected.username, '1234567')
        onUserChange(newUser)
      } catch (err: any) {
        console.error('Failed to authenticate persona:', err)
        // Fallback for offline mode so UI remains testable
        onUserChange({
          id: selected.id,
          name: selected.label,
          role: selected.role,
          tenantId: selected.tenantId,
          token: user.token,
        })
      }
    }
  }

  return (
    <header className="top-header">
      <div className="header-title-group">
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <h1>Insurer Claims Workspace</h1>
          <span className="mono-tag" style={{ color: '#06B6D4', borderColor: 'rgba(6,182,212,0.3)' }}>
            <Cpu size={12} style={{ display: 'inline', marginRight: '4px' }} />
            Quantum Phase 4
          </span>
          <span className="mono-tag" style={{ color: '#8B5CF6', borderColor: 'rgba(139,92,246,0.3)' }}>
            <KeyRound size={12} style={{ display: 'inline', marginRight: '4px' }} />
            ML-DSA-65 PQC
          </span>
        </div>
        <p>Tenant: <strong style={{ color: tenant.color }}>{tenant.name}</strong> • Role: <strong>{user.role}</strong> ({user.id})</p>
      </div>

      <div className="header-actions">
        {/* Quick Demo Actor Switcher */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: '#F8FAFC', padding: '6px 12px', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
          <UserCheck size={16} color="var(--brand-orange)" />
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Persona:</span>
          <select 
            value={user.id} 
            onChange={handleActorSwitch}
            style={{
              background: 'transparent',
              color: '#0F172A',
              border: 'none',
              fontSize: '12px',
              fontWeight: 700,
              cursor: 'pointer',
              outline: 'none',
            }}
          >
            {demoActors.map(a => (
              <option key={a.id} value={a.id} style={{ background: '#FFFFFF', color: '#0F172A' }}>
                [{a.role}] {a.label}
              </option>
            ))}
          </select>
        </div>

        <button 
          className="btn btn-ghost" 
          onClick={onRefresh} 
          disabled={isRefreshing}
          title="Refresh claim records from Cloudflare D1"
        >
          <RefreshCw size={14} className={isRefreshing ? 'animate-spin' : ''} />
          <span>{isRefreshing ? 'Syncing...' : 'Sync D1'}</span>
        </button>

        <button 
          className="btn btn-ghost" 
          onClick={() => {
            ApiService.logout()
            window.location.reload()
          }}
          title="Log out"
        >
          <LogOut size={14} />
        </button>
      </div>
    </header>
  )
}
