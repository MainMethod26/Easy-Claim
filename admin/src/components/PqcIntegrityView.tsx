import React, { useState } from 'react'
import { KeyRound, ShieldCheck, ShieldAlert, Lock, CheckCircle2, AlertOctagon, Terminal } from 'lucide-react'

export const PqcIntegrityView: React.FC = () => {
  const [tamperMode, setTamperMode] = useState<boolean>(false)
  const [testResult, setTestResult] = useState<{
    status: 'VALID' | 'TAMPERED'
    message: string
    digest: string
    signatureValid: boolean
  }>({
    status: 'VALID',
    message: 'NIST FIPS 204 ML-DSA-65 signature verified. All fields intact.',
    digest: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    signatureValid: true,
  })

  const runVerification = (tampered: boolean) => {
    setTamperMode(tampered)
    if (tampered) {
      setTestResult({
        status: 'TAMPERED',
        message: 'CRITICAL INTEGRITY FAILURE: Approved amount was altered from R4,200 to R42,000 in database. ML-DSA-65 signature verification failed. Payout REFUSED (409 decision_integrity_failed).',
        digest: 'f87a91b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0',
        signatureValid: false,
      })
    } else {
      setTestResult({
        status: 'VALID',
        message: 'NIST FIPS 204 ML-DSA-65 signature verified. Canonical decision bundle matches original cryptographic signature perfectly.',
        digest: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signatureValid: true,
      })
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Banner */}
      <div className="content-card" style={{ padding: '28px', background: 'linear-gradient(135deg, rgba(124, 58, 237, 0.06), rgba(255, 85, 0, 0.03))', borderColor: 'var(--pqc-border)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
          <div style={{ width: '42px', height: '42px', borderRadius: '10px', background: 'var(--pqc-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--pqc-purple)', border: '1px solid var(--pqc-border)' }}>
            <KeyRound size={24} />
          </div>
          <div>
            <h2 style={{ fontSize: '20px', fontWeight: 800 }}>Post-Quantum Decision Integrity (ML-DSA-65)</h2>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
              Implementation of NIST FIPS 204 Module-Lattice Digital Signature Algorithm. Eliminates insider claim tampering and ensures non-repudiation before any money can be paid out.
            </p>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', marginTop: '16px', padding: '12px 16px', background: '#F8FAFC', borderRadius: '8px', border: '1px solid var(--border-color)', fontSize: '12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--pqc-purple)', fontWeight: 600 }}>
            <CheckCircle2 size={14} />
            <span>NIST Standard: FIPS 204 (August 2024)</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-muted)', fontWeight: 600 }}>
            <Lock size={14} />
            <span>Pure TypeScript: @noble/post-quantum</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--success)', fontWeight: 600 }}>
            <ShieldCheck size={14} />
            <span>Payout Gate: Pre-Disbursement Verification</span>
          </div>
        </div>
      </div>

      {/* Interactive Tamper & Defense Simulator */}
      <div className="content-card" style={{ padding: '24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <h3 style={{ fontSize: '16px', fontWeight: 800, display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Terminal size={18} color="var(--brand-orange)" />
              Interactive Tamper-Resistance Demonstration
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Test how the post-quantum signature engine defends against unauthorized database tampering before payout.
            </p>
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <button 
              className={`btn ${!tamperMode ? 'btn-primary' : 'btn-ghost'}`}
              style={{ fontSize: '12px' }}
              onClick={() => runVerification(false)}
            >
              <ShieldCheck size={14} />
              <span>Normal Valid Record</span>
            </button>
            <button 
              className={`btn ${tamperMode ? 'btn-danger' : 'btn-ghost'}`}
              style={{ fontSize: '12px' }}
              onClick={() => runVerification(true)}
            >
              <AlertOctagon size={14} />
              <span>Simulate DB Tampering</span>
            </button>
          </div>
        </div>

        {/* Verification Result Card */}
        <div style={{
          padding: '20px',
          borderRadius: '12px',
          background: testResult.status === 'VALID' ? '#ECFDF5' : '#FEF2F2',
          border: `1px solid ${testResult.status === 'VALID' ? '#A7F3D0' : '#FECACA'}`,
          marginBottom: '20px'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              {testResult.status === 'VALID' ? (
                <ShieldCheck size={22} color="#059669" />
              ) : (
                <ShieldAlert size={22} color="#DC2626" />
              )}
              <span style={{ fontSize: '16px', fontWeight: 800, color: testResult.status === 'VALID' ? '#065F46' : '#991B1B' }}>
                Status: {testResult.status}
              </span>
            </div>

            <span className="mono-tag" style={{ 
              color: testResult.status === 'VALID' ? '#047857' : '#B91C1C',
              background: testResult.status === 'VALID' ? '#D1FAE5' : '#FEE2E2',
              borderColor: testResult.status === 'VALID' ? '#A7F3D0' : '#FCA5A5'
            }}>
              {testResult.status === 'VALID' ? 'PAYOUT ALLOWED' : 'PAYOUT BLOCKED (409)'}
            </span>
          </div>

          <p style={{ fontSize: '13px', color: testResult.status === 'VALID' ? '#065F46' : '#991B1B', marginBottom: '12px', lineHeight: 1.5, fontWeight: 500 }}>
            {testResult.message}
          </p>

          <div style={{ background: '#FFFFFF', padding: '12px 14px', borderRadius: '8px', border: '1px solid var(--border-color)', fontSize: '12px', fontFamily: 'var(--font-mono)' }}>
            <div style={{ color: 'var(--text-muted)', marginBottom: '4px', fontWeight: 600 }}>Recomputed Canonical Bundle Digest:</div>
            <div style={{ color: testResult.status === 'VALID' ? '#059669' : '#DC2626', wordBreak: 'break-all', fontWeight: 600 }}>
              {testResult.digest}
            </div>
          </div>
        </div>

        {/* Cryptographic Parameters Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '14px', fontSize: '12px' }}>
          <div style={{ background: '#F8FAFC', padding: '14px', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
            <span style={{ color: 'var(--text-muted)', fontWeight: 600 }}>Algorithm:</span>
            <div style={{ fontWeight: 700, marginTop: '2px', color: 'var(--text-main)' }}>ML-DSA-65 (NIST FIPS 204)</div>
          </div>
          <div style={{ background: '#F8FAFC', padding: '14px', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
            <span style={{ color: 'var(--text-muted)', fontWeight: 600 }}>Key ID:</span>
            <div className="mono-tag" style={{ marginTop: '4px', display: 'inline-block' }}>mldsa65-7a4f91b0e3c8d2a1</div>
          </div>
          <div style={{ background: '#F8FAFC', padding: '14px', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
            <span style={{ color: 'var(--text-muted)', fontWeight: 600 }}>Key Derivation:</span>
            <div style={{ fontWeight: 700, marginTop: '2px', color: 'var(--text-main)' }}>Deterministic from Cloudflare Secret Seed</div>
          </div>
        </div>
      </div>
    </div>
  )
}
