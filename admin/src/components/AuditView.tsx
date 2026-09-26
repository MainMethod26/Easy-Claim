import React, { useEffect, useState } from 'react'
import { Activity, CheckCircle2, Lock, Database, Loader2 } from 'lucide-react'
import { ApiService } from '../services/api'

export const AuditView: React.FC = () => {
  const [events, setEvents] = useState<any[]>([])
  const [loading, setLoading] = useState<boolean>(true)

  useEffect(() => {
    let mounted = true
    const load = async () => {
      setLoading(true)
      const data = await ApiService.fetchAuditEvents()
      if (mounted) {
        setEvents(data)
        setLoading(false)
      }
    }
    load()
    return () => {
      mounted = false
    }
  }, [])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div className="content-card" style={{ padding: '28px', background: 'linear-gradient(135deg, rgba(37, 99, 235, 0.06), rgba(255, 85, 0, 0.03))', borderColor: 'rgba(37, 99, 235, 0.2)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
          <div style={{ width: '42px', height: '42px', borderRadius: '10px', background: '#EFF6FF', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#2563EB', border: '1px solid #BFDBFE' }}>
            <Activity size={24} />
          </div>
          <div>
            <h2 style={{ fontSize: '20px', fontWeight: 800 }}>Append-Only Audit Ledger & Governance</h2>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
              Complete auditability with acting tenant isolation, server-generated request IDs, and SQLite triggers blocking UPDATE and DELETE statements.
            </p>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', marginTop: '16px', padding: '12px 16px', background: '#F8FAFC', borderRadius: '8px', border: '1px solid var(--border-color)', fontSize: '12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#2563EB', fontWeight: 600 }}>
            <Database size={14} />
            <span>SQLite Trigger Protected (D1)</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--success)', fontWeight: 600 }}>
            <CheckCircle2 size={14} />
            <span>Every Refusal & Transition Recorded</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-muted)', fontWeight: 600 }}>
            <Lock size={14} />
            <span>Server-Generated Request IDs</span>
          </div>
        </div>
      </div>

      {/* Audit Events Table */}
      <div className="content-card">
        <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border-color)' }}>
          <h3 style={{ fontSize: '15px', fontWeight: 700 }}>Recent Tenant Audit Log Entries</h3>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table className="claims-table">
            <thead>
              <tr>
                <th>Event Action</th>
                <th>Actor & Tenant</th>
                <th>Resource Target</th>
                <th>Outcome</th>
                <th>Request ID (Trace)</th>
                <th>Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                      <Loader2 size={18} className="spin" color="var(--brand-orange)" />
                      <span>Reading append-only audit trail from D1 database...</span>
                    </div>
                  </td>
                </tr>
              ) : events.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                    No audit records logged for this tenant yet.
                  </td>
                </tr>
              ) : (
                events.map((evt) => (
                  <tr key={evt.id}>
                    <td>
                      <span style={{ fontWeight: 700, color: 'var(--text-main)' }}>{evt.action}</span>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600 }}>{evt.actor_id || 'System'}</div>
                      <div className="mono-tag" style={{ marginTop: '2px', display: 'inline-block' }}>
                        {evt.actor_tenant_id || 'Global'} • {evt.actor_role || 'SYSTEM'}
                      </div>
                    </td>
                    <td>
                      <span className="mono-tag">{evt.resource_id || evt.resource_type}</span>
                    </td>
                    <td>
                      <span className="badge" style={{
                        background: evt.outcome === 'success' ? '#ECFDF5' : '#FEF2F2',
                        color: evt.outcome === 'success' ? '#047857' : '#DC2626',
                        borderColor: evt.outcome === 'success' ? '#A7F3D0' : '#FECACA'
                      }}>
                        {evt.outcome}
                      </span>
                    </td>
                    <td>
                      <code className="mono-tag">{evt.request_id ? `${evt.request_id.slice(0, 18)}...` : 'n/a'}</code>
                    </td>
                    <td style={{ color: 'var(--text-dim)', fontSize: '12px' }}>
                      {evt.occurred_at ? new Date(evt.occurred_at).toLocaleString() : 'Just now'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
