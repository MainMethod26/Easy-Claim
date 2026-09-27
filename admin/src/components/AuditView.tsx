import React, { useCallback, useEffect, useState } from 'react'
import { Activity, Loader2 } from 'lucide-react'
import type { AuditEvent, Role } from '../types'
import { ApiService, describeError } from '../services/api'
import { formatDateTime, NONE } from '../services/mappers'

/**
 * Append-only audit log. INSURER_ADMIN reads GET /tenant/audit (own tenant), SUPERADMIN reads
 * GET /admin/audit (platform). No other endpoint is used and there is no fallback.
 */
export const AuditView: React.FC<{ role: Role }> = ({ role }) => {
  const [events, setEvents] = useState<AuditEvent[]>([])
  const [nextBefore, setNextBefore] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async (before: string | null) => {
    setLoading(true)
    try {
      const page = await ApiService.fetchAuditEvents(before)
      setEvents((prev) => (before ? [...prev, ...page.events] : page.events))
      setNextBefore(page.nextBefore)
      setError(null)
    } catch (err) {
      setError(describeError(err))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load(null)
  }, [load])

  const scope = role === 'SUPERADMIN' ? 'Platform audit log' : 'Tenant audit log'

  return (
    <div className="content-card">
      <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', gap: '10px' }}>
        <Activity size={18} color="#2563EB" />
        <div>
          <h3 style={{ fontSize: '15px', fontWeight: 700 }}>{scope}</h3>
          <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Newest first, as recorded by the backend.</p>
        </div>
      </div>

      {error && (
        <div role="alert" style={{ margin: '16px 24px', padding: '10px 12px', background: '#FEF2F2', border: '1px solid #FECACA', borderRadius: '8px', color: '#B91C1C', fontSize: '13px' }}>
          Could not load the audit log: {error}
        </div>
      )}

      <div style={{ overflowX: 'auto' }}>
        <table className="claims-table">
          <thead>
            <tr>
              <th>Time</th>
              <th>Action</th>
              <th>Actor</th>
              <th>Resource</th>
              <th>Outcome</th>
            </tr>
          </thead>
          <tbody>
            {events.length === 0 && !loading ? (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  {error ? 'Not available.' : 'No audit events.'}
                </td>
              </tr>
            ) : (
              events.map((evt) => (
                <tr key={evt.id}>
                  <td style={{ color: 'var(--text-dim)', fontSize: '12px', whiteSpace: 'nowrap' }}>{formatDateTime(evt.occurredAt)}</td>
                  <td>
                    <span style={{ fontWeight: 700, color: 'var(--text-main)' }}>{evt.action}</span>
                  </td>
                  <td>
                    <div style={{ fontWeight: 600 }}>{evt.actorId ?? NONE}</div>
                    <div className="mono-tag" style={{ marginTop: '2px', display: 'inline-block' }}>{evt.actorRole ?? NONE}</div>
                  </td>
                  <td>
                    <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{evt.resourceType ?? NONE}</div>
                    <span className="mono-tag">{evt.resourceId ?? NONE}</span>
                  </td>
                  <td>
                    <span
                      className="badge"
                      style={{
                        background: evt.outcome === 'success' ? '#ECFDF5' : '#FEF2F2',
                        color: evt.outcome === 'success' ? '#047857' : '#DC2626',
                        borderColor: evt.outcome === 'success' ? '#A7F3D0' : '#FECACA',
                      }}
                    >
                      {evt.outcome ?? NONE}
                    </span>
                  </td>
                </tr>
              ))
            )}
            {loading && (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '24px', color: 'var(--text-muted)' }}>
                  <Loader2 size={18} className="spin" style={{ display: 'inline', marginRight: '8px' }} />
                  Loading audit events…
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {nextBefore && !loading && (
        <div style={{ padding: '16px 24px' }}>
          <button className="btn btn-ghost" onClick={() => load(nextBefore)}>Load older events</button>
        </div>
      )}
    </div>
  )
}
