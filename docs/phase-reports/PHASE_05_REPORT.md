# EasyClaim Phase 5 Report — Post-quantum decision integrity (ML-DSA)

Date: 2026-09-26 · Branch `phase-5-pqc` from `main` @ `efccb8c` (Phases 0–4 merged) · **Uncommitted, awaiting approval.**

## 1. Objective
Make every claim decision tamper-evident with a post-quantum signature (master plan §11), so that an edit to a recorded
decision — even by someone with database access — is detected and blocks payout.

## 2. Starting state (precheck)
`claim_decisions` existed (Phase 3, insert-only via triggers) with a reserved, always-NULL `integrity_signature`; decisions
already carried `evidence_digest` (Phase 2 alignment) and `risk_signal` (Phase 4 completion). No signing library, no key,
no verify route. Suite: 246 Worker tests passing. User decisions: merge Phase 4 first (done, PR #5); key = Cloudflare secret seed.

## 3. What was implemented
| Item | Where | Status |
|---|---|---|
| ML-DSA-65 signer/verifier, canonical decision bundle, key derivation from seed, key id | `src/security/integrity.ts` | IMPLEMENTED, TESTED |
| Signature columns (`integrity_alg`, `integrity_key_id`, `integrity_bundle_digest`) | `migrations/0008_decision_integrity.sql` | IMPLEMENTED |
| Sign at `/decide`, fail closed without a key | `src/endpoints/claimsInsurer.ts` | IMPLEMENTED, TESTED |
| Verify before payout | `/pay` | IMPLEMENTED, TESTED |
| `GET /claims/:id/decision/verify`, `GET /integrity/public-key` | `src/integrity/routes.ts`, `src/index.ts` | IMPLEMENTED, TESTED |
| Local key setup, test key per run | `scripts/setup-dev-vars.mjs`, `.dev.vars.example`, `vitest.config.mts` | IMPLEMENTED |
| Dependency | `@noble/post-quantum` 0.7.1 (MIT, pure TS; pulls `@noble/hashes`, `curves`, `ciphers`) | added |

Details: `docs/security/PQC_DECISION_INTEGRITY.md`.

## 4. Tests
`npm test`: **17 files, 264 passed** (246 before + 18 in `test/decisionIntegrity.test.ts`). `npm run typecheck`: clean.
`npm audit`: 0 vulnerabilities. Phase 0–4 suites unchanged and passing (signing is transparent to them).

## 5. Attacks
| Attack | Result |
|---|---|
| Insider edits amount / outcome / destination / reason / decision-maker / screening signal / evidence digest | `TAMPERED`; `/pay` 409 `decision_integrity_failed`, audited |
| Signature stripped | `UNSIGNED`; payout refused |
| Attacker re-signs a forged bundle with their own ML-DSA key | `UNKNOWN_KEY` (or `TAMPERED` if they keep our key id) |
| Signature copied from another decision / garbage signature | `TAMPERED`, no crash |
| Deployment without a key | decisions refused (503), verify `UNAVAILABLE`, payout refused |
| Different deployment key | `UNKNOWN_KEY` |
| Customer / assessor tries to decide | still 403 — the signature grants no authority |
Live evidence: `docs/security/evidence/PHASE_05_LIVE_DEMO.log`.

## 6. Known limitations
Single current key (no registry/rotation); seed held by the Worker as a Cloudflare secret (no KMS/HSM); the Worker that
signs could sign a bad decision if compromised (the signature protects against later edits, not a compromised signer);
no trusted timestamp; decisions recorded before Phase 5 are `UNSIGNED` and cannot be paid until re-decided; the
demo environment runs locally.

## 7. Demo
`npm run setup:local` (adds `MLDSA_SEED`) → migrate → `npm run dev -- --port 8789` →
`bash docs/security/evidence/live-demo-p5.sh part1` → stop the server → `… tamper` → start the server → `… part2`.
Postman folder 10 has the verify, public-key and forged-pay requests.

## 8. What we can honestly claim
"Every EasyClaim decision is signed with ML-DSA-65 (NIST FIPS 204, a post-quantum signature). Any later change to the
decision — amount, outcome, payout destination, evidence or screening context — is detected, and payout is refused."
Not: "EasyClaim is quantum-safe" (TLS, JWT HS256 and storage are unchanged), or "keys are HSM-protected".
