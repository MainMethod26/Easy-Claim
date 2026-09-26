# Quantum screening: security boundary

The screening signal is **advisory data**. Cyber controls decide who may act; humans decide outcomes; the signal only
informs. Every rule below is enforced in code and tested (`test/screeningSignals.test.ts`, `test/quantumScreening.test.ts`).

```
request ─► requireActor (JWT) ─► requireRole(ASSESSOR|MANAGER) ─► strict params ─► loadAuthorizedClaim('insurer')
        ─► [POST /screen only] transitionClaim(Verified → Screening)  ◄── the signal plays no part in this
        ─► readRiskSignals (read-only)  ─► audit screening.signal_attached / signal_read (with digest)
        ─► response { riskSignals: { bands, recommendation, versions, digest, advisory: true } }
```

| Rule | How it is enforced | Test |
|---|---|---|
| No client can supply or change a score | No write route; `/screen` ignores its body; `/decide` and all bodies are strict (`quantumScore` → 400); POST/PUT/PATCH/DELETE on `/risk-signals` → 404 | QUANTUM-08, Attack 1 |
| Signal inherits auth, RBAC, tenant, ownership | same chain as every insurer route; customers 403, other tenant 404 (audited), no token 401 | QUANTUM-06/07, Attacks 2–3 |
| Signal never moves a claim | read happens after the transition; nothing in `src/screening/` calls `transitionClaim` or writes `claims`; from Screening, `/pay` and `/decide` are still 409 | QUANTUM-09, Attack 5 |
| Humans decide | HIGH-anomaly claim still needs review → MANAGER decision (with reason) → payout; NORMAL and "no signal" behave identically | QUANTUM-12 |
| Auditable | `screening.signal_attached` (on `/screen`) and `screening.signal_read` (on `GET /risk-signals`) with band, recommendation, model, execution and SHA-256 `digest` — never feature values | QUANTUM-10 |
| The decision records what the human saw | `/decide` stores `signalSummary` (band, scores, model, digest) in `claim_decisions.risk_signal`; it is never an input to any rule | QUANTUM-10 |
| Stored signals are tamper-evident | migration 0007: `UPDATE` on `screening_signals` aborts; a re-import (`INSERT OR REPLACE`, how a new model run is published) gets a new `imported_at` and a different digest than the one already in the audit trail and decision | Attack 4 |
| Only valid signals are shown | DB CHECKs (0–1 scores, 3 interpretations, simulator/hardware, FK to claims) + defensive reader returns null for malformed rows | reader unit test |
| No hardware claim unless true | `execution` column is `simulator` for every committed run | — |

What this is **not**: cryptographic integrity. A party with database access can replace a row; the digest in the
append-only audit trail and in the decision record makes that detectable, and Phase 5 (ML-DSA over the decision bundle,
which includes `risk_signal`) is the planned cryptographic protection.
