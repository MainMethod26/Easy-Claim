import { useState, useEffect, useCallback } from 'react'
import type { AuthUser, Claim } from './types'
import { ApiService } from './services/api'
import { Header } from './components/Header'
import { Sidebar } from './components/Sidebar'
import { StatsCards } from './components/StatsCards'
import { ClaimsTable } from './components/ClaimsTable'
import { ClaimDetailDrawer } from './components/ClaimDetailDrawer'
import { QuantumScreeningView } from './components/QuantumScreeningView'
import { PqcIntegrityView } from './components/PqcIntegrityView'
import { AuditView } from './components/AuditView'

export function App() {
  const [user, setUser] = useState<AuthUser>(() => {
    const existing = ApiService.getUser()
    if (existing) return existing

    // Default to Discovery Claims Manager for immediate, feature-complete access
    const defaultActor = ApiService.getDemoActors()[0]
    return {
      id: defaultActor.id,
      name: defaultActor.label,
      role: defaultActor.role,
      tenantId: defaultActor.tenantId,
      token: `dev_token_${defaultActor.role.toLowerCase()}_${defaultActor.tenantId}`,
    }
  })

  const [activeTab, setActiveTab] = useState<string>('claims')
  const [claims, setClaims] = useState<Claim[]>([])
  const [selectedClaim, setSelectedClaim] = useState<Claim | null>(null)
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false)

  const loadClaims = useCallback(async () => {
    setIsRefreshing(true)
    try {
      const data = await ApiService.fetchClaims()
      setClaims(data)
      if (selectedClaim) {
        const updated = data.find(c => c.id === selectedClaim.id)
        if (updated) setSelectedClaim(updated)
      }
    } finally {
      setIsRefreshing(false)
    }
  }, [selectedClaim])

  useEffect(() => {
    let mounted = true
    if (!user.token || user.token.startsWith('dev_token_')) {
      const defaultActor = ApiService.getDemoActors()[0]
      ApiService.login(defaultActor.username, '1234567')
        .then((newUser) => {
          if (mounted) setUser(newUser)
        })
        .catch((err) => {
          console.warn('Initial backend login failed, continuing in preview mode:', err)
          if (mounted) loadClaims()
        })
    } else {
      loadClaims()
    }
    return () => {
      mounted = false
    }
  }, [user.tenantId, user.token, loadClaims])

  const handleClaimUpdated = () => {
    loadClaims()
  }

  return (
    <div className="app-container">
      {/* Sidebar */}
      <Sidebar 
        user={user} 
        activeTab={activeTab} 
        setActiveTab={setActiveTab} 
        claimsCount={claims.length} 
      />

      {/* Main Content */}
      <div className="main-wrapper">
        <Header 
          user={user} 
          onUserChange={(newUser) => {
            setUser(newUser)
            setSelectedClaim(null)
          }}
          onRefresh={loadClaims}
          isRefreshing={isRefreshing}
        />

        <main className="page-body">
          {activeTab === 'claims' && (
            <>
              <StatsCards claims={claims} />
              <ClaimsTable 
                claims={claims} 
                onSelectClaim={(claim) => setSelectedClaim(claim)}
                selectedClaimId={selectedClaim?.id}
              />
            </>
          )}

          {activeTab === 'quantum' && <QuantumScreeningView />}

          {activeTab === 'pqc' && <PqcIntegrityView />}

          {activeTab === 'audit' && <AuditView />}
        </main>
      </div>

      {/* Slide-in Claims Workspace Drawer */}
      {selectedClaim && (
        <ClaimDetailDrawer 
          claim={selectedClaim}
          user={user}
          onClose={() => setSelectedClaim(null)}
          onClaimUpdated={handleClaimUpdated}
        />
      )}
    </div>
  )
}

export default App
