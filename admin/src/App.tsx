import { useState, useEffect, useCallback } from 'react'
import type { ClaimSummary, Session } from './types'
import { ApiService, describeError } from './services/api'
import { Header } from './components/Header'
import { Sidebar, type TabId, tabsFor } from './components/Sidebar'
import { StatsCards } from './components/StatsCards'
import { ClaimsTable } from './components/ClaimsTable'
import { ClaimDetailDrawer } from './components/ClaimDetailDrawer'
import { QuantumScreeningView } from './components/QuantumScreeningView'
import { PqcIntegrityView } from './components/PqcIntegrityView'
import { AuditView } from './components/AuditView'
import { SignInForm } from './components/SignInForm'

export function App() {
  // Only a session issued by the backend; no default user, no dev token, no auto-login.
  const [session, setSession] = useState<Session | null>(() => {
    const s = ApiService.getSession()
    return s && tabsFor(s.actor.role).length > 0 ? s : null
  })
  const [signInNotice, setSignInNotice] = useState<string | null>(null)
  const [switchingUser, setSwitchingUser] = useState(false)

  // Accept a backend-issued session only for roles this portal serves (not CUSTOMER).
  const acceptSession = (s: Session) => {
    setSwitchingUser(false)
    if (tabsFor(s.actor.role).length === 0) {
      ApiService.logout()
      setSession(null)
      setSignInNotice(`The ${s.actor.role} account "${s.actor.username}" cannot use the insurer portal. Sign in with a staff account.`)
      return
    }
    setSignInNotice(null)
    setSession(s)
  }

  useEffect(
    () =>
      ApiService.onUnauthorized(() => {
        setSession(null)
        setSwitchingUser(false)
        setSignInNotice('Your session has expired or was rejected. Please sign in again.')
      }),
    []
  )

  if (!session) {
    return (
      <SignInForm
        notice={signInNotice}
        onSignedIn={acceptSession}
      />
    )
  }

  return (
    <>
      {/* Keyed by token so all per-user state resets when the signed-in user changes. */}
      <Workspace
        key={session.token}
        session={session}
        onSwitchUser={() => setSwitchingUser(true)}
        onSignOut={() => {
          ApiService.logout()
          setSignInNotice(null)
          setSession(null)
        }}
      />
      {switchingUser && (
        <SignInForm
          onCancel={() => setSwitchingUser(false)}
          onSignedIn={acceptSession}
        />
      )}
    </>
  )
}

interface WorkspaceProps {
  session: Session
  onSwitchUser: () => void
  onSignOut: () => void
}

function Workspace({ session, onSwitchUser, onSignOut }: WorkspaceProps) {
  const role = session.actor.role
  const tabs = tabsFor(role)
  const canListClaims = tabs.includes('claims')

  const [activeTab, setActiveTab] = useState<TabId>(tabs[0] ?? 'pqc')
  const [claims, setClaims] = useState<ClaimSummary[]>([])
  const [claimsError, setClaimsError] = useState<string | null>(null)
  const [claimsLoaded, setClaimsLoaded] = useState(false)
  const [selectedClaimId, setSelectedClaimId] = useState<string | null>(null)
  const [isRefreshing, setIsRefreshing] = useState(false)

  const loadClaims = useCallback(async () => {
    if (!canListClaims) return
    setIsRefreshing(true)
    try {
      setClaims(await ApiService.fetchClaims())
      setClaimsError(null)
    } catch (err) {
      setClaimsError(describeError(err))
    } finally {
      setClaimsLoaded(true)
      setIsRefreshing(false)
    }
  }, [canListClaims])

  useEffect(() => {
    void loadClaims()
  }, [loadClaims])

  return (
    <div className="app-container">
      <Sidebar
        session={session}
        tabs={tabs}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        claimsCount={canListClaims && claimsLoaded && !claimsError ? claims.length : null}
      />

      <div className="main-wrapper">
        <Header
          session={session}
          onSwitchUser={onSwitchUser}
          onSignOut={onSignOut}
          onRefresh={canListClaims ? loadClaims : undefined}
          isRefreshing={isRefreshing}
        />

        <main className="page-body">
          {activeTab === 'claims' && canListClaims && (
            <>
              {claimsError && (
                <div role="alert" style={{ padding: '12px 16px', background: '#FEF2F2', border: '1px solid #FECACA', borderRadius: '8px', color: '#B91C1C', fontSize: '13px', marginBottom: '16px' }}>
                  Could not load claims: {claimsError}
                </div>
              )}
              {claimsLoaded && !claimsError && <StatsCards claims={claims} />}
              <ClaimsTable
                claims={claims}
                loading={!claimsLoaded}
                onSelectClaim={(claim) => setSelectedClaimId(claim.id)}
                selectedClaimId={selectedClaimId ?? undefined}
              />
            </>
          )}

          {activeTab === 'quantum' && <QuantumScreeningView role={role} />}

          {activeTab === 'pqc' && <PqcIntegrityView role={role} />}

          {activeTab === 'audit' && <AuditView role={role} />}
        </main>
      </div>

      {selectedClaimId && (
        <ClaimDetailDrawer
          key={selectedClaimId}
          claimId={selectedClaimId}
          role={role}
          onClose={() => setSelectedClaimId(null)}
          onClaimUpdated={loadClaims}
        />
      )}
    </div>
  )
}

export default App
