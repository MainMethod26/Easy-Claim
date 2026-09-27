import React, { useState } from 'react'
import { ShieldCheck, LogIn, Loader2 } from 'lucide-react'
import type { Session } from '../types'
import { ApiService, PERSONA_USERNAMES, describeError } from '../services/api'

interface SignInFormProps {
  onSignedIn: (session: Session) => void
  /** When given, the form is shown over an existing session and can be dismissed. */
  onCancel?: () => void
  notice?: string | null
}

/**
 * Real sign-in against POST /auth/login. No password is stored or pre-filled; the persona list
 * only fills in a username. The displayed user/role changes only after the backend accepts the
 * credentials (ApiService.login replaces the session on success only).
 */
export const SignInForm: React.FC<SignInFormProps> = ({ onSignedIn, onCancel, notice }) => {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (busy) return
    setBusy(true)
    setError(null)
    try {
      const session = await ApiService.login(username.trim(), password)
      setPassword('')
      onSignedIn(session)
    } catch (err) {
      setError(describeError(err))
    } finally {
      setBusy(false)
    }
  }

  const field: React.CSSProperties = {
    width: '100%',
    background: '#F8FAFC',
    border: '1px solid #CBD5E1',
    borderRadius: 'var(--radius-sm)',
    padding: '10px 12px',
    color: '#0F172A',
    fontSize: '14px',
    outline: 'none',
  }
  const label: React.CSSProperties = { display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px', color: '#0F172A' }

  return (
    <div
      style={{
        position: onCancel ? 'fixed' : 'relative',
        inset: onCancel ? 0 : undefined,
        minHeight: onCancel ? undefined : '100vh',
        background: onCancel ? 'rgba(15, 23, 42, 0.6)' : '#F1F5F9',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 300,
        padding: '16px',
      }}
    >
      <form
        onSubmit={submit}
        style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-color)',
          borderRadius: 'var(--radius-lg)',
          padding: '28px',
          width: '400px',
          maxWidth: '100%',
          boxShadow: '0 20px 50px rgba(15, 23, 42, 0.15)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '6px' }}>
          <ShieldCheck size={22} color="var(--brand-orange)" />
          <h2 style={{ fontSize: '18px', fontWeight: 800, color: '#0F172A' }}>{onCancel ? 'Switch user' : 'Sign in to EasyClaim'}</h2>
        </div>
        <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '18px' }}>
          Insurer operations. Your role and tenant come from your account on the server.
        </p>

        {notice && (
          <div role="status" style={{ padding: '10px 12px', background: '#FFFBEB', border: '1px solid #FDE68A', borderRadius: '8px', color: '#92400E', fontSize: '12px', marginBottom: '14px' }}>
            {notice}
          </div>
        )}

        <div style={{ marginBottom: '14px' }}>
          <label style={label} htmlFor="signin-persona">Demo account (fills in the username only)</label>
          <select
            id="signin-persona"
            value=""
            onChange={(e) => {
              if (e.target.value) setUsername(e.target.value)
            }}
            style={{ ...field, cursor: 'pointer' }}
          >
            <option value="">Choose an account…</option>
            {PERSONA_USERNAMES.map((p) => (
              <option key={p.username} value={p.username}>
                {p.username} — {p.hint}
              </option>
            ))}
          </select>
        </div>

        <div style={{ marginBottom: '14px' }}>
          <label style={label} htmlFor="signin-username">Username</label>
          <input
            id="signin-username"
            type="text"
            autoComplete="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            style={field}
            required
          />
        </div>

        <div style={{ marginBottom: '18px' }}>
          <label style={label} htmlFor="signin-password">Password</label>
          <input
            id="signin-password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            style={field}
            required
          />
        </div>

        {error && (
          <div role="alert" style={{ padding: '10px 12px', background: '#FEF2F2', border: '1px solid #FECACA', borderRadius: '8px', color: '#B91C1C', fontSize: '13px', marginBottom: '14px' }}>
            {error}
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
          {onCancel && (
            <button type="button" className="btn btn-ghost" onClick={onCancel} disabled={busy}>
              Cancel
            </button>
          )}
          <button type="submit" className="btn btn-primary" disabled={busy || !username.trim() || !password}>
            {busy ? <Loader2 size={14} className="spin" /> : <LogIn size={14} />}
            <span>{busy ? 'Signing in…' : 'Sign in'}</span>
          </button>
        </div>
      </form>
    </div>
  )
}
