import React from 'react'
import type { Session } from '../types'
import { RefreshCw, LogOut, UserCog } from 'lucide-react'

interface HeaderProps {
  session: Session
  onSwitchUser: () => void
  onSignOut: () => void
  onRefresh?: () => void
  isRefreshing: boolean
}

/**
 * Shows the signed-in actor exactly as the backend returned it. Switching user opens the sign-in
 * form; the displayed user/role only changes after the backend accepts the new credentials.
 */
export const Header: React.FC<HeaderProps> = ({ session, onSwitchUser, onSignOut, onRefresh, isRefreshing }) => {
  const { actor } = session

  return (
    <header className="top-header">
      <div className="header-title-group">
        <h1>Insurer Claims Workspace</h1>
        <p>
          Signed in as <strong>{actor.displayName ?? actor.username}</strong> ({actor.username}) • Role: <strong>{actor.role}</strong> • Tenant:{' '}
          <strong>{actor.tenantId ?? '—'}</strong>
        </p>
      </div>

      <div className="header-actions">
        {onRefresh && (
          <button className="btn btn-ghost" onClick={onRefresh} disabled={isRefreshing} title="Reload claims from the backend">
            <RefreshCw size={14} className={isRefreshing ? 'animate-spin' : ''} />
            <span>{isRefreshing ? 'Loading…' : 'Refresh'}</span>
          </button>
        )}

        <button className="btn btn-ghost" onClick={onSwitchUser} title="Sign in as a different user">
          <UserCog size={14} />
          <span>Switch user</span>
        </button>

        <button className="btn btn-ghost" onClick={onSignOut} title="Sign out">
          <LogOut size={14} />
        </button>
      </div>
    </header>
  )
}
