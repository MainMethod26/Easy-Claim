# Phase 4 — Quantum screening (index)

| Document | What it covers |
|---|---|
| `QUANTUM_SCREENING_ARCHITECTURE.md` | Architecture (lifecycle, trust boundary, experiment flow diagrams). This is the brief's "QUANTUM_ARCHITECTURE.md". |
| `FEATURE_PIPELINE.md` | The five features, preprocessing, bands, versions |
| `CLASSICAL_VS_QUANTUM.md` | Measured comparison and what we can honestly claim |
| `QUANTUM_SECURITY_BOUNDARY.md` | How the signal is kept advisory, auditable and tamper-evident |
| `PHASE_04_PRECHECK.md`, `PHASE_04_REPORT.md` | Original Phase 4 experiment precheck and report |
| `../phase-reports/PHASE_04_COMPLETION_PRECHECK.md`, `../phase-reports/PHASE_04_REPORT.md` | Completion precheck and final Phase 4 report |
| `evidence/PHASE_04_LIVE_DEMO.log`, `evidence/PHASE_04_COMPLETION_LIVE_DEMO.log` | Live runs against `wrangler dev` |

One sentence: a quantum-kernel one-class anomaly score, computed offline on the simulator alongside a classical baseline
with the same features, is attached read-only to a claim at Screening as `REVIEW_REQUIRED` / `STANDARD_REVIEW` context
for a human; it never approves, rejects, pays or moves a claim.
