import React from 'react'
import { Cpu, CheckCircle2, BarChart3, Info } from 'lucide-react'

export const QuantumScreeningView: React.FC = () => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Intro Banner */}
      <div className="content-card" style={{ padding: '28px', background: 'linear-gradient(135deg, #F0FDFA, #FFFFFF)', borderColor: '#A5F3FC' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '14px' }}>
          <div style={{ width: '44px', height: '44px', borderRadius: '12px', background: '#ECFEFF', border: '1px solid #A5F3FC', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--quantum-cyan)' }}>
            <Cpu size={24} />
          </div>
          <div>
            <h2 style={{ fontSize: '20px', fontWeight: 800, color: '#0F172A' }}>Quantum Anomaly Screening Track (Phase 4)</h2>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
              Experimental quantum-kernel one-class anomaly detection for the SCREENING stage, compared with a classical One-Class SVM baseline on identical features.
            </p>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', marginTop: '16px', padding: '12px 16px', background: '#FFFFFF', borderRadius: '8px', border: '1px solid #CCFBF1', fontSize: '12px', boxShadow: 'var(--shadow-sm)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#0369A1', fontWeight: 600 }}>
            <CheckCircle2 size={14} />
            <span>Honest Reporting: Simulator Only</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-muted)', fontWeight: 600 }}>
            <Info size={14} />
            <span>Advisory Signal: Never Overrides Human Decision</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--brand-orange)', fontWeight: 600 }}>
            <BarChart3 size={14} />
            <span>5 Normalized Feature Vectors</span>
          </div>
        </div>
      </div>

      {/* Model Architecture & Features Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '20px' }}>
        <div className="content-card" style={{ padding: '24px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: 700, color: '#0F172A', marginBottom: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Cpu size={16} color="var(--quantum-cyan)" />
            Quantum Kernel Architecture
          </h3>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
            Uses a PennyLane variational circuit to map normalized claim vectors into quantum Hilbert state space $\phi(x)$, computing the fidelity kernel matrix:
          </p>
          <div style={{ background: '#F0FDFA', border: '1px solid #A5F3FC', padding: '12px', borderRadius: '8px', fontFamily: 'var(--font-mono)', fontSize: '13px', color: '#0E7490', marginBottom: '16px', fontWeight: 600 }}>
            K(x_i, x_j) = |⟨ϕ(x_i) | ϕ(x_j)⟩|²
          </div>
          <ul style={{ fontSize: '13px', color: '#334155', display: 'flex', flexDirection: 'column', gap: '8px', listStyle: 'none' }}>
            <li>• <strong>Feature Map:</strong> Angle-embedding on 5 simulated qubits</li>
            <li>• <strong>Framework:</strong> PennyLane + Scikit-learn OneClassSVM</li>
            <li>• <strong>Signal Digest:</strong> SHA-256 hashed and bound to claim decisions</li>
          </ul>
        </div>

        <div className="content-card" style={{ padding: '24px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: 700, color: '#0F172A', marginBottom: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <BarChart3 size={16} color="var(--brand-orange)" />
            The 5 Evaluated Claim Features
          </h3>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '14px' }}>
            Derived directly from operational claims data without invented business metrics:
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', borderRadius: '6px', border: '1px solid #E2E8F0' }}>
              <span style={{ fontWeight: 600, color: '#0F172A' }}>1. Claimed Amount (cents)</span>
              <code className="mono-tag">log1p scaled</code>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', borderRadius: '6px', border: '1px solid #E2E8F0' }}>
              <span style={{ fontWeight: 600, color: '#0F172A' }}>2. Policy Age (days)</span>
              <code className="mono-tag">duration since start</code>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', borderRadius: '6px', border: '1px solid #E2E8F0' }}>
              <span style={{ fontWeight: 600, color: '#0F172A' }}>3. Incident Filing Delay</span>
              <code className="mono-tag">lag days</code>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', borderRadius: '6px', border: '1px solid #E2E8F0' }}>
              <span style={{ fontWeight: 600, color: '#0F172A' }}>4. Loss Cause Risk Score</span>
              <code className="mono-tag">categorical weight</code>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#F8FAFC', borderRadius: '6px', border: '1px solid #E2E8F0' }}>
              <span style={{ fontWeight: 600, color: '#0F172A' }}>5. Historical Prior Claims</span>
              <code className="mono-tag">frequency count</code>
            </div>
          </div>
        </div>
      </div>

      {/* Advisory Bands & Recommendations */}
      <div className="content-card" style={{ padding: '24px' }}>
        <h3 style={{ fontSize: '15px', fontWeight: 700, color: '#0F172A', marginBottom: '16px' }}>
          Screening Signal Contract & Advisory Bands
        </h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px' }}>
          <div style={{ border: '1px solid #A7F3D0', background: '#ECFDF5', borderRadius: '12px', padding: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ fontWeight: 800, color: '#047857' }}>NORMAL</span>
              <span className="mono-tag" style={{ background: '#FFFFFF' }}>&lt; 80th Percentile</span>
            </div>
            <p style={{ fontSize: '12px', color: '#065F46' }}>
              Claim parameters align with historical distribution. Recommended: <strong>STANDARD_REVIEW</strong>.
            </p>
          </div>

          <div style={{ border: '1px solid #FDE68A', background: '#FFFBEB', borderRadius: '12px', padding: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ fontWeight: 800, color: '#B45309' }}>ELEVATED</span>
              <span className="mono-tag" style={{ background: '#FFFFFF' }}>80th - 95th Percentile</span>
            </div>
            <p style={{ fontSize: '12px', color: '#92400E' }}>
              Outlier detected in filing delay or claimed ratio. Recommended: <strong>REVIEW_REQUIRED</strong>.
            </p>
          </div>

          <div style={{ border: '1px solid #FECDD3', background: '#FFF1F2', borderRadius: '12px', padding: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ fontWeight: 800, color: '#BE123C' }}>HIGH_ANOMALY</span>
              <span className="mono-tag" style={{ background: '#FFFFFF' }}>&gt; 95th Percentile</span>
            </div>
            <p style={{ fontSize: '12px', color: '#9F1239' }}>
              Significant statistical deviation across multiple features. Mandatory assessor verification.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
