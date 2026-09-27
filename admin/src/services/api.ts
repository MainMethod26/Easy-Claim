import type { AuthUser, Claim, DecisionIntegrity, EvidenceItem, PayoutDetails, RiskSignals, Role, TenantId, TimelineEntry } from '../types'

const AUTH_STORAGE_KEY = 'easyclaim_admin_auth'

export class ApiService {
  private static user: AuthUser | null = (() => {
    try {
      const stored = localStorage.getItem(AUTH_STORAGE_KEY)
      return stored ? JSON.parse(stored) : null
    } catch {
      return null
    }
  })()

  static getUser(): AuthUser | null {
    return this.user
  }

  static setUser(user: AuthUser | null) {
    this.user = user
    if (user) {
      localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(user))
    } else {
      localStorage.removeItem(AUTH_STORAGE_KEY)
    }
  }

  static getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    }
    if (this.user?.token) {
      headers['Authorization'] = `Bearer ${this.user.token}`
    }
    return headers
  }

  // Pre-configured Dev & Production Demo Profiles matching backend seed
  static getDemoActors(): { username: string; label: string; role: Role; tenantId: TenantId; id: string; description: string }[] {
    return [
      {
        id: 'manager_a1',
        username: 'manager_discovery',
        label: 'Discovery Claims Manager (Thabo Sithole)',
        role: 'MANAGER',
        tenantId: 'ins_discovery',
        description: 'Full approval authority, ML-DSA post-quantum decision signing & payouts for Discovery tenant',
      },
      {
        id: 'assessor_a1',
        username: 'assessor_discovery',
        label: 'Discovery Assessor (Lerato Dlamini)',
        role: 'ASSESSOR',
        tenantId: 'ins_discovery',
        description: 'Intake verification, quantum screening radar & evidence analysis for Discovery tenant',
      },
      {
        id: 'usr_admin_discovery',
        username: 'admin_discovery',
        label: 'Discovery Insurer Admin (Admin Staff)',
        role: 'INSURER_ADMIN',
        tenantId: 'ins_discovery',
        description: 'Tenant administration, staff management & read-only audit log for Discovery',
      },
      {
        id: 'manager_b1',
        username: 'manager_sanlam',
        label: 'Sanlam Claims Manager (Johan van der Merwe)',
        role: 'MANAGER',
        tenantId: 'ins_sanlam',
        description: 'Managerial sign-off & simulated settlement execution for Sanlam tenant',
      },
      {
        id: 'assessor_b1',
        username: 'assessor_sanlam',
        label: 'Sanlam Assessor (Zanele Khumalo)',
        role: 'ASSESSOR',
        tenantId: 'ins_sanlam',
        description: 'Case intake & risk screening for Sanlam tenant',
      },
      {
        id: 'usr_admin_sanlam',
        username: 'admin_sanlam',
        label: 'Sanlam Insurer Admin (Admin Staff)',
        role: 'INSURER_ADMIN',
        tenantId: 'ins_sanlam',
        description: 'Tenant administration & staff management for Sanlam',
      },
      {
        id: 'usr_superadmin',
        username: 'superadmin',
        label: 'EasyClaim Superadmin (Platform Operator)',
        role: 'SUPERADMIN',
        tenantId: 'ins_discovery',
        description: 'Platform overview, tenants & platform-wide security audit',
      },
    ]
  }

  // Authenticate against Cloudflare Worker backend (/api/v1/auth/login)
  static async login(username: string, password = '1234567'): Promise<AuthUser> {
    const res = await fetch('/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    })

    if (!res.ok) {
      const err = await res.json().catch(() => ({}))
      throw new Error(err.error || `Authentication failed for ${username}`)
    }

    const data = await res.json()
    const actor = data.actor || {}
    const user: AuthUser = {
      id: actor.id || username,
      name: actor.displayName || username,
      role: (actor.role as Role) || 'MANAGER',
      tenantId: (actor.tenantId as TenantId) || 'ins_discovery',
      token: data.token,
    }
    this.setUser(user)
    return user
  }

  static logout() {
    this.setUser(null)
  }

  // Fetch real claims for the active tenant
  static async fetchClaims(): Promise<Claim[]> {
    const res = await fetch('/api/v1/claims?limit=100', {
      headers: this.getHeaders(),
    })
    if (!res.ok) {
      const err = await res.json().catch(() => ({}))
      console.error('Failed to fetch claims from server:', err)
      return []
    }
    const data = await res.json()
    return Array.isArray(data.claims) ? data.claims : []
  }

  // Fetch single claim details
  static async fetchClaimById(claimId: string): Promise<Claim | null> {
    const res = await fetch(`/api/v1/claims/${claimId}`, {
      headers: this.getHeaders(),
    })
    if (!res.ok) return null
    const data = await res.json()
    return data.claim || null
  }

  // Fetch real claim lifecycle timeline
  static async fetchTimeline(claimId: string): Promise<TimelineEntry[]> {
    const res = await fetch(`/api/v1/claims/${claimId}/timeline`, {
      headers: this.getHeaders(),
    })
    if (!res.ok) return []
    const data = await res.json()
    return data.timeline || []
  }

  // Fetch real quantum anomaly screening signal
  static async fetchRiskSignals(claimId: string): Promise<RiskSignals | null> {
    const res = await fetch(`/api/v1/claims/${claimId}/risk-signals`, {
      headers: this.getHeaders(),
    })
    if (!res.ok) return null
    const data = await res.json()
    return data.riskSignals || data.signals || null
  }

  // Fetch real ML-DSA-65 post-quantum decision verification
  static async verifyDecisionIntegrity(claimId: string): Promise<DecisionIntegrity> {
    const res = await fetch(`/api/v1/claims/${claimId}/decision/verify`, {
      headers: this.getHeaders(),
    })
    if (!res.ok) {
      return {
        status: 'UNAVAILABLE',
        decisionId: null,
      }
    }
    const data = await res.json()
    if (data.integrity) {
      return {
        ...data.integrity,
        decisionId: data.decisionId ?? null,
        algorithm: data.integrity.alg || data.integrity.algorithm || 'ML-DSA-65',
      }
    }
    return data
  }

  // Fetch real payout details
  static async fetchPayout(claimId: string): Promise<PayoutDetails | null> {
    const res = await fetch(`/api/v1/claims/${claimId}/payout`, {
      headers: this.getHeaders(),
    })
    if (!res.ok) return null
    return await res.json()
  }

  // Fetch real evidence items
  static async fetchEvidence(claimId: string): Promise<EvidenceItem[]> {
    const res = await fetch(`/api/v1/claims/${claimId}/evidence`, {
      headers: this.getHeaders(),
    })
    if (!res.ok) return []
    const data = await res.json()
    const list = data.evidence || []
    return list.map((item: any) => ({
      id: item.id,
      claim_id: claimId,
      filename: item.display_name || item.filename || item.storage_key || 'evidence_file',
      display_name: item.display_name || item.filename,
      mime_type: item.mime_type || 'application/octet-stream',
      byte_size: item.size_bytes || item.byte_size || 0,
      size_bytes: item.size_bytes,
      sha256_hash: item.sha256 || item.sha256_hash,
      sha256: item.sha256,
      created_at: item.created_at || new Date().toISOString(),
      integrityStatus: 'VALID',
    }))
  }

  // Fetch real append-only audit trail
  static async fetchAuditEvents(): Promise<any[]> {
    const role = this.user?.role
    let endpoint = '/api/v1/activities/audit-trail'
    if (role === 'INSURER_ADMIN') {
      endpoint = '/api/v1/tenant/audit?limit=50'
    } else if (role === 'SUPERADMIN') {
      endpoint = '/api/v1/admin/audit?limit=50'
    }

    let res = await fetch(endpoint, {
      headers: this.getHeaders(),
    })
    
    // Fallback if role-specific audit route is forbidden or unavailable
    if (!res.ok && endpoint !== '/api/v1/activities/audit-trail') {
      res = await fetch('/api/v1/activities/audit-trail', {
        headers: this.getHeaders(),
      })
    }

    if (!res.ok) return []
    const data = await res.json()
    const list = data.events || data.trail || []
    return list.map((evt: any) => ({
      ...evt,
      id: evt.id || `evt_${Math.random()}`,
      action: evt.action,
      actor_id: evt.actor_id ?? evt.actorId,
      actor_tenant_id: evt.actor_tenant_id ?? evt.actorTenantId ?? evt.tenantId,
      actor_role: evt.actor_role ?? evt.actorRole,
      resource_id: evt.resource_id ?? evt.resourceId,
      resource_type: evt.resource_type ?? evt.resourceType,
      outcome: evt.outcome,
      request_id: evt.request_id ?? evt.requestId,
      occurred_at: evt.occurred_at ?? evt.occurredAt ?? new Date().toISOString(),
    }))
  }

  // Real State Machine Action Handlers
  static async executeTransition(claimId: string, action: 'verify' | 'screen' | 'review' | 'request-info'): Promise<{ ok: boolean; message: string }> {
    const res = await fetch(`/api/v1/claims/${claimId}/${action}`, {
      method: 'POST',
      headers: this.getHeaders(),
    })
    const data = await res.json().catch(() => ({}))
    if (res.ok) {
      return { ok: true, message: `Successfully transitioned to ${action}` }
    }
    return { ok: false, message: data.error || 'Transition denied' }
  }

  static async decideClaim(claimId: string, outcome: 'Approved' | 'Rejected', reason: string, approvedAmountCents?: number): Promise<{ ok: boolean; message: string }> {
    const res = await fetch(`/api/v1/claims/${claimId}/decide`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ outcome, reason, approvedAmountCents }),
    })
    const data = await res.json().catch(() => ({}))
    if (res.ok) {
      return { ok: true, message: 'Decision recorded and cryptographically signed with ML-DSA-65' }
    }
    return { ok: false, message: data.error || 'Decision failed' }
  }

  static async payClaim(claimId: string): Promise<{ ok: boolean; message: string }> {
    const res = await fetch(`/api/v1/claims/${claimId}/pay`, {
      method: 'POST',
      headers: {
        ...this.getHeaders(),
        'Idempotency-Key': `payout_${claimId}_${Date.now()}`,
      },
    })
    const data = await res.json().catch(() => ({}))
    if (res.ok) {
      return { ok: true, message: 'Simulated payout executed after ML-DSA-65 signature verification' }
    }
    return { ok: false, message: data.error || 'Payout refused' }
  }
}
