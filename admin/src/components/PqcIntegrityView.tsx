import React, { useEffect, useState } from 'react'
import { KeyRound, Info } from 'lucide-react'
import type { PlatformIntegrity, PublicKeyInfo, Role, TenantOverviewSummary } from '../types'
import { ApiService, describeError } from '../services/api'
import { formatDateTime, NONE } from '../services/mappers'

type Load<T> = { state: 'loading' } | { state: 'ok'; data: T } | { state: 'error'; error: string } | { state: 'n/a' }

/**
 * Decision-integrity overview, from the backend only:
 * - GET /integrity/public-key (any signed-in role): the key decisions are signed with.
 * - GET /admin/integrity (SUPERADMIN) or GET /tenant/overview (INSURER_ADMIN): signed/unsigned
 *   decision counts and recent verification results.
 * Per-claim verification (GET /claims/:id/decision/verify) is in the claim drawer.
 */
export const PqcIntegrityView: React.FC<{ role: Role }> = ({ role }) => {
  const [key, setKey] = useState<Load<PublicKeyInfo | null>>({ state: 'loading' })
  const [platform, setPlatform] = useState<Load<PlatformIntegrity | null>>(role === 'SUPERADMIN' ? { state: 'loading' } : { state: 'n/a' })
  const [tenant, setTenant] = useState<Load<TenantOverviewSummary | null>>(role === 'INSURER_ADMIN' ? { state: 'loading' } : { state: 'n/a' })

  useEffect(() => {
    let live = true
    const wrap = <T,>(p: Promise<T>, set: (l: Load<T>) => void) =>
      p.then(
        (data) => live && set({ state: 'ok', data }),
        (err) => live && set({ state: 'error', error: describeError(err) })
      )
    void wrap(ApiService.fetchPublicKey(), setKey)
    if (role === 'SUPERADMIN') void wrap(ApiService.fetchPlatformIntegrity(), setPlatform)
    if (role === 'INSURER_ADMIN') void wrap(ApiService.fetchTenantOverview(), setTenant)
    return () => {
      live = false
    }
  }, [role])

  const counts =
    platform.state === 'ok' && platform.data
      ? { signed: platform.data.decisions.signed, unsigned: platform.data.decisions.unsigned, verifications: platform.data.verificationsInWindow, windowDays: platform.data.windowDays }
      : tenant.state === 'ok' && tenant.data?.integrity
        ? { signed: tenant.data.integrity.signed, unsigned: tenant.data.integrity.unsigned, verifications: tenant.data.integrity.verificationsInWindow, windowDays: null }
        : null
  const countsLoad = role === 'SUPERADMIN' ? platform : tenant

  const cell: React.CSSProperties = { background: '#F8FAFC', padding: '14px', borderRadius: '8px', border: '1px solid var(--border-color)' }
  const lbl: React.CSSProperties = { color: 'var(--text-muted)', fontWeight: 600, fontSize: '12px' }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div className="content-card" style={{ padding: '24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '10px' }}>
          <KeyRound size={22} color="var(--pqc-purple)" />
          <h2 style={{ fontSize: '18px', fontWeight: 800 }}>Decision integrity</h2>
        </div>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
          Each recorded decision is signed by the server. A payout is refused unless the stored decision still
          verifies. Verify a specific claim’s decision from its claim drawer.
        </p>
      </div>

      <div className="content-card" style={{ padding: '24px' }}>
        <h3 style={{ fontSize: '15px', fontWeight: 700, marginBottom: '14px' }}>Signing key</h3>
        {key.state === 'loading' && <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Loading…</p>}
        {key.state === 'error' && <p style={{ fontSize: '13px', color: '#B91C1C' }}>Not available: {key.error}</p>}
        {key.state === 'ok' && !key.data && <p style={{ fontSize: '13px', color: '#B91C1C' }}>Not available: unexpected response.</p>}
        {key.state === 'ok' && key.data && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px', fontSize: '12px' }}>
            <div style={cell}><span style={lbl}>Algorithm</span><div style={{ fontWeight: 700 }}>{key.data.alg}{key.data.standard ? ` (${key.data.standard})` : ''}</div></div>
            <div style={cell}><span style={lbl}>Key ID</span><div className="mono-tag" style={{ marginTop: '4px', display: 'inline-block' }}>{key.data.keyId}</div></div>
            <div style={cell}><span style={lbl}>Bundle version</span><div style={{ fontWeight: 700 }}>{key.data.bundleVersion ?? NONE}</div></div>
            <div style={cell}><span style={lbl}>Context</span><div style={{ fontWeight: 700 }}>{key.data.context ?? NONE}</div></div>
          </div>
        )}
      </div>

      <div className="content-card" style={{ padding: '24px' }}>
        <h3 style={{ fontSize: '15px', fontWeight: 700, marginBottom: '14px' }}>{role === 'SUPERADMIN' ? 'Platform decisions' : 'Tenant decisions'}</h3>
        {countsLoad.state === 'n/a' && (
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'flex', gap: '8px', alignItems: 'center' }}>
            <Info size={14} /> Aggregate integrity figures are not available to your role.
          </p>
        )}
        {countsLoad.state === 'loading' && <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Loading…</p>}
        {countsLoad.state === 'error' && <p style={{ fontSize: '13px', color: '#B91C1C' }}>Not available: {countsLoad.error}</p>}
        {countsLoad.state === 'ok' && !counts && <p style={{ fontSize: '13px', color: '#B91C1C' }}>Not available: unexpected response.</p>}
        {counts && (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '14px', fontSize: '12px' }}>
              <div style={cell}><span style={lbl}>Signed decisions</span><div style={{ fontSize: '22px', fontWeight: 800 }}>{counts.signed}</div></div>
              <div style={cell}><span style={lbl}>Unsigned decisions</span><div style={{ fontSize: '22px', fontWeight: 800 }}>{counts.unsigned}</div></div>
            </div>
            <div style={{ marginTop: '14px', fontSize: '12px', color: 'var(--text-muted)' }}>
              Verification results{counts.windowDays ? ` (last ${counts.windowDays} days)` : ''}:{' '}
              {Object.keys(counts.verifications).length === 0
                ? 'none recorded'
                : Object.entries(counts.verifications).map(([k, v]) => `${k}: ${v}`).join(', ')}
            </div>
            {platform.state === 'ok' && platform.data && (
              <div style={{ marginTop: '8px', fontSize: '12px', color: 'var(--text-muted)' }}>
                By key:{' '}
                {platform.data.decisions.byKeyId.length === 0 ? NONE : platform.data.decisions.byKeyId.map((k) => `${k.keyId}: ${k.count}`).join(', ')}
                {' • '}Generated: {formatDateTime(platform.data.generatedAt)}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
