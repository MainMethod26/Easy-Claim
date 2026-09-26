# Post-quantum decision integrity (Phase 5, ML-DSA-65)

Status: IMPLEMENTED and TESTED (branch `phase-5-pqc`). Standard: NIST FIPS 204 ML-DSA, parameter set ML-DSA-65.
Library: `@noble/post-quantum` 0.7.1 (pure TypeScript, MIT), pinned in `package.json`.

## Why
A recorded decision (who approved what amount, to which destination, on which evidence and screening signal) is the most
valuable record in EasyClaim. Phase 3 made it insert-only with database triggers — but anyone with database administration
rights can drop a trigger and edit a row. A digital signature makes such an edit detectable by anyone holding the public
key, and ML-DSA is designed to stay secure against future quantum computers ("sign today, still verifiable later").

## What is signed
The **decision bundle** — a fixed-order JSON array:
`["easyclaim-decision-bundle-v1", id, claim_id, tenant_id, outcome, reason, previous_stage, claimed_amount_cents,
approved_amount_cents, destination_hash, actor_id, actor_role, decided_at, rules_version, evidence_digest, risk_signal]`.
So one signature covers the decision itself, the payout destination (Phase 3), the evidence set (Phase 2, `evidence_digest`)
and the screening signal the manager saw (Phase 4, `risk_signal`). Signed with the FIPS 204 context string
`easyclaim/decision/v1` (domain separation).

## Where it happens (`src/security/integrity.ts`)
| Step | Where | Behaviour |
|---|---|---|
| Sign | `POST /claims/:id/decide` | After all Phase 3 checks, the bundle is signed and `integrity_signature`, `integrity_alg`, `integrity_key_id`, `integrity_bundle_digest` are written with the row, in the same D1 batch as `Review → Decision` (migration `0008`). |
| Fail closed | `/decide` | Missing/invalid `MLDSA_SEED` → `503 integrity_unavailable`, audited, no decision recorded. |
| Verify | `GET /claims/:id/decision/verify` | Owner or the claim's tenant staff. `VALID` / `TAMPERED` / `UNSIGNED` / `UNKNOWN_KEY` / `UNAVAILABLE` / `NO_DECISION`. Audited `decision.integrity_verified`. |
| Enforce | `POST /claims/:id/pay` | Verifies **before reading any decision field**; anything but `VALID` → `409 decision_integrity_failed`, audited `payout.blocked`. |
| Publish | `GET /integrity/public-key` | Any authenticated actor: algorithm, key id, context, bundle version, base64 public key (1952 bytes). |

## Keys
32-byte seed in the `MLDSA_SEED` secret (`npm run setup:local` generates it into `.dev.vars`; deployed:
`wrangler secret put MLDSA_SEED`). Keypair derived with FIPS 204 KeyGen from the seed and cached per isolate. Key id =
`mldsa65-` + first 16 hex of SHA-256(public key). Tests use a fresh random seed per run; no key material is committed.
**Not implemented (DECISION REQUIRED):** key custody in a KMS/HSM, rotation with a key registry (verification today
trusts only the current key; older signatures report `UNKNOWN_KEY` after a rotation), and external timestamping.

## What it proves and what it does not
- Proves: the stored decision fields are exactly those signed at decision time by the holder of the EasyClaim key.
- Does not prove the decision was right, and does not authorise anything: who may decide is still enforced by
  authentication, tenant isolation, RBAC and the state machine. A signature does not stop a compromised Worker (which holds
  the seed) from signing a bad decision; it stops **after-the-fact** edits.
- Performance: ML-DSA-65 sign ≈ tens of ms in pure JS; one signature per decision, one verification per payout/verify call.

## Tests and evidence
`test/decisionIntegrity.test.ts` (18 cases): signature sizes and algorithm; VALID for owner/tenant; independent verification
with only the public key; access control; seven tampering cases (amount, outcome, destination, reason, decision-maker,
screening signal, evidence digest) → `TAMPERED` + payout blocked; stripped signature → `UNSIGNED`; attacker re-signing with
their own key → `UNKNOWN_KEY` / `TAMPERED`; copied or garbage signatures; missing seed fails closed; other deployment key;
signing grants no authority. Live: `docs/security/evidence/PHASE_05_LIVE_DEMO.log` (sign → VALID → insider edits the
approved amount in D1 → TAMPERED → payout refused).
