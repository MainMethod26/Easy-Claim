import React, { useEffect, useState } from 'react'
import { Cpu, Info } from 'lucide-react'
import type { PlatformIntegrity, Role, ScreeningMix } from '../types'
import { ApiService, describeError } from '../services/api'
import { formatDateTime } from '../services/mappers'

type Data =
  | { kind: 'none' }
  | { kind: 'loading' }
  | { kind: 'error'; error: string }
  | { kind: 'tenant'; mix: ScreeningMix | null; generatedAt: string | null }
  | { kind: 'platform'; data: PlatformIntegrity | null }

/**
 * Screening overview. Aggregate numbers come only from the backend:
 * INSURER_ADMIN → GET /tenant/overview (screening), SUPERADMIN → GET /admin/integrity (screening).
 * ASSESSOR/MANAGER have no aggregate endpoint; they see each claim's signal in the claim drawer.
 */
export const QuantumScreeningView: React.FC<{ role: Role }> = ({ role }) => {
  const hasAggregate = role === 'INSURER_ADMIN' || role === 'SUPERADMIN'
  const [data, setData] = useState<Data>(hasAggregate ? { kind: 'loading' } : { kind: 'none' })

  useEffect(() => {
    if (!hasAggregate) return
    let live = true
    const run = async () => {
      try {
        const next: Data =
          role === 'SUPERADMIN'
            ? { kind: 'platform', data: await ApiService.fetchPlatformIntegrity() }
            : await ApiService.fetchTenantOverview().then((o) => ({ kind: 'tenant' as const, mix: o?.screening ?? null, generatedAt: o?.generatedAt ?? null }))
        if (live) setData(next)
      } catch (err) {
        if (live) setData({ kind: 'error', error: describeError(err) })
      }
    }
    void run()
    return () => {
      live = false
    }
  }, [role, hasAggregate])

  const mix: ScreeningMix | null =
    data.kind === 'tenant' ? data.mix : data.kind === 'platform' && data.data ? data.data.screening : null

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div className="content-card" style={{ padding: '24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '10px' }}>
          <Cpu size={22} color="var(--quantum-cyan)" />
          <h2 style={{ fontSize: '18px', fontWeight: 800, color: '#0F172A' }}>Screening signals (advisory)</h2>
        </div>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
          Signals are computed offline (a classical one-class model and a quantum-kernel one-class model on the same
          features) and imported read-only. They inform a human reviewer; they never move a claim or decide an outcome.
          Bands: <strong>NORMAL</strong>, <strong>ELEVATED</strong>, <strong>HIGH</strong>.
        </p>
      </div>

      <div className="content-card" style={{ padding: '24px' }}>
        <h3 style={{ fontSize: '15px', fontWeight: 700, color: '#0F172A', marginBottom: '14px' }}>
          {role === 'SUPERADMIN' ? 'Platform screening mix' : 'Screening mix'}
        </h3>

        {data.kind === 'none' && (
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'flex', gap: '8px', alignItems: 'center' }}>
            <Info size={14} /> Aggregate screening figures are not available to your role. Open a claim to see its signal.
          </p>
        )}
        {data.kind === 'loading' && <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Loading…</p>}
        {data.kind === 'error' && <p style={{ fontSize: '13px', color: '#B91C1C' }}>Not available: {data.error}</p>}
        {(data.kind === 'tenant' || data.kind === 'platform') && !mix && (
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Not available: the response did not include screening figures.</p>
        )}

        {mix && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '12px' }}>
            {(['NORMAL', 'ELEVATED', 'HIGH', 'unscreened'] as const).map((k) => (
              <div key={k} style={{ background: '#F8FAFC', border: '1px solid var(--border-color)', borderRadius: '8px', padding: '14px' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase' }}>
                  {k === 'unscreened' ? 'No signal' : k}
                </div>
                <div style={{ fontSize: '22px', fontWeight: 800, color: '#0F172A' }}>{mix[k]}</div>
              </div>
            ))}
          </div>
        )}

        {data.kind === 'platform' && data.data && (
          <div style={{ marginTop: '16px', fontSize: '12px', color: 'var(--text-muted)', display: 'grid', gap: '6px' }}>
            <div>
              Execution:{' '}
              {Object.keys(data.data.screening.byExecution).length === 0
                ? '—'
                : Object.entries(data.data.screening.byExecution).map(([k, v]) => `${k}: ${v}`).join(', ')}
            </div>
            <div>
              Model versions:{' '}
              {data.data.screening.byModelVersion.length === 0
                ? '—'
                : data.data.screening.byModelVersion.map((m) => `${m.modelVersion}: ${m.count}`).join(', ')}
            </div>
            <div>Generated: {formatDateTime(data.data.generatedAt)}</div>
          </div>
        )}
        {data.kind === 'tenant' && mix && (
          <div style={{ marginTop: '16px', fontSize: '12px', color: 'var(--text-muted)' }}>Generated: {formatDateTime(data.generatedAt)}</div>
        )}
      </div>
    </div>
  )
}
