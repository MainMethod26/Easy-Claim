/**
 * Phase 5: post-quantum decision integrity (ML-DSA-65, NIST FIPS 204).
 *
 * Every claim decision is serialised into a canonical DECISION BUNDLE and signed with ML-DSA-65
 * at the moment it is recorded. The signature, key id and bundle digest are stored with the
 * insert-only decision row. Anyone holding the published public key can later check that the
 * decision (outcome, amounts, destination, evidence digest, screening signal, who, when, why)
 * is exactly what was signed. `/pay` refuses to pay a decision whose signature does not verify.
 *
 * A signature proves a decision was not altered after it was recorded. It does NOT authorise a
 * decision: authentication, tenant isolation, RBAC and the state machine still decide who may
 * record one.
 *
 * Key: a 32-byte seed in the MLDSA_SEED secret (`.dev.vars` locally, `wrangler secret put`
 * deployed); the keypair is derived deterministically (FIPS 204 KeyGen from seed) and cached per
 * isolate. Key rotation / KMS / HSM custody: PLANNED (DECISION REQUIRED).
 * Library: @noble/post-quantum (audited-style, pure TypeScript, MIT), pinned.
 */
import { ml_dsa65 } from '@noble/post-quantum/ml-dsa.js'
import { sha256Hex } from './ledger'

export const INTEGRITY_ALG = 'ML-DSA-65' as const
export const BUNDLE_VERSION = 'easyclaim-decision-bundle-v1'
/** FIPS 204 context string: domain-separates EasyClaim decision signatures from any other use of the key. */
const CONTEXT = new TextEncoder().encode('easyclaim/decision/v1')

export interface Signer {
  keyId: string
  publicKey: Uint8Array
  secretKey: Uint8Array
}

let cache: { seed: string; signer: Signer } | null = null

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2)
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16)
  return out
}

export function toBase64(bytes: Uint8Array): string {
  let s = ''
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  return btoa(s)
}

function fromBase64(b64: string): Uint8Array | null {
  try {
    const s = atob(b64)
    const out = new Uint8Array(s.length)
    for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i)
    return out
  } catch {
    return null
  }
}

/**
 * Returns the signer for the configured seed, or null when MLDSA_SEED is missing or malformed
 * (callers fail closed: no decision is recorded unsigned).
 */
export async function getSigner(seedHex: string | undefined): Promise<Signer | null> {
  const seed = (seedHex ?? '').trim().toLowerCase()
  if (!/^[0-9a-f]{64}$/.test(seed)) return null
  if (cache && cache.seed === seed) return cache.signer
  const { publicKey, secretKey } = ml_dsa65.keygen(hexToBytes(seed))
  const keyId = `mldsa65-${(await sha256Hex(toBase64(publicKey))).slice(0, 16)}`
  const signer = { keyId, publicKey, secretKey }
  cache = { seed, signer }
  return signer
}

/** The fields that make up a decision. Order is fixed; changing it is a new BUNDLE_VERSION. */
export interface DecisionBundleFields {
  id: string
  claim_id: string
  tenant_id: string | null
  outcome: string
  reason: string
  previous_stage: string
  claimed_amount_cents: number | null
  approved_amount_cents: number | null
  destination_hash: string | null
  actor_id: string
  actor_role: string
  decided_at: string
  rules_version: string
  evidence_digest: string | null
  risk_signal: string | null
}

export function canonicalBundle(d: DecisionBundleFields): string {
  return JSON.stringify([
    BUNDLE_VERSION,
    d.id,
    d.claim_id,
    d.tenant_id,
    d.outcome,
    d.reason,
    d.previous_stage,
    d.claimed_amount_cents,
    d.approved_amount_cents,
    d.destination_hash,
    d.actor_id,
    d.actor_role,
    d.decided_at,
    d.rules_version,
    d.evidence_digest,
    d.risk_signal,
  ])
}

export interface DecisionSignature {
  integrity_alg: typeof INTEGRITY_ALG
  integrity_key_id: string
  integrity_bundle_digest: string
  integrity_signature: string
}

export async function signDecision(signer: Signer, d: DecisionBundleFields): Promise<DecisionSignature> {
  const bundle = canonicalBundle(d)
  const signature = ml_dsa65.sign(new TextEncoder().encode(bundle), signer.secretKey, { context: CONTEXT })
  return {
    integrity_alg: INTEGRITY_ALG,
    integrity_key_id: signer.keyId,
    integrity_bundle_digest: await sha256Hex(bundle),
    integrity_signature: toBase64(signature),
  }
}

export type IntegrityStatus = 'VALID' | 'TAMPERED' | 'UNSIGNED' | 'UNKNOWN_KEY' | 'UNAVAILABLE'

export interface IntegrityResult {
  status: IntegrityStatus
  alg: string | null
  keyId: string | null
  bundleDigest: string | null
  recomputedDigest: string
}

/**
 * Re-serialises the stored decision and verifies its signature with the current public key.
 * UNSIGNED: no signature stored (pre-Phase 5 or stripped). UNKNOWN_KEY: signed by a key this
 * deployment does not hold. TAMPERED: the stored fields or signature no longer match.
 * UNAVAILABLE: the verifier is not configured (fail closed).
 */
export async function verifyDecision(
  seedHex: string | undefined,
  d: DecisionBundleFields & Partial<Record<keyof DecisionSignature, string | null>>
): Promise<IntegrityResult> {
  const bundle = canonicalBundle(d)
  const recomputedDigest = await sha256Hex(bundle)
  const base = { alg: d.integrity_alg ?? null, keyId: d.integrity_key_id ?? null, bundleDigest: d.integrity_bundle_digest ?? null, recomputedDigest }
  if (!d.integrity_signature || !d.integrity_key_id) return { status: 'UNSIGNED', ...base }
  const signer = await getSigner(seedHex)
  if (!signer) return { status: 'UNAVAILABLE', ...base }
  if (d.integrity_alg !== INTEGRITY_ALG || d.integrity_key_id !== signer.keyId) return { status: 'UNKNOWN_KEY', ...base }
  const sig = fromBase64(d.integrity_signature)
  let ok = false
  try {
    ok = sig !== null && ml_dsa65.verify(sig, new TextEncoder().encode(bundle), signer.publicKey, { context: CONTEXT })
  } catch {
    ok = false
  }
  return { status: ok ? 'VALID' : 'TAMPERED', ...base }
}
