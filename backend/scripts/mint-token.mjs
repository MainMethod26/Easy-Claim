#!/usr/bin/env node
// Mint LOCAL development tokens signed with JWT_SECRET from backend/.dev.vars.
//
//   npm run token -- --sub user123 --role CUSTOMER
//   npm run token -- --sub assessor_a1 --role ASSESSOR --tenant ins_discovery
//   npm run token -- --demo      # one token per demo actor, printed
//   npm run token -- --postman   # writes postman/EasyClaim.local.postman_environment.json (gitignored)
//
// Options: --ttl <seconds> (default 3600, max 8h for staff / 24h for customers, mirroring the
// server), --iss, --aud, --secret (override .dev.vars). The claim rules match
// src/security/actor.ts so the script refuses to mint a token the server would reject.
//
// Local demos only; a deployed environment gets tokens from the real identity provider /
// auth service (see docs/security/BACKEND_SECURITY_HANDOFF.md).
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { sign } from 'hono/jwt'

const backendDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const ID = /^[A-Za-z0-9_-]{1,64}$/
const ROLES = ['CUSTOMER', 'ASSESSOR', 'MANAGER', 'ADMIN']
const MAX_TTL = { CUSTOMER: 24 * 3600, ASSESSOR: 8 * 3600, MANAGER: 8 * 3600, ADMIN: 8 * 3600 }

function parseDotEnv(file) {
  if (!existsSync(file)) return {}
  const out = {}
  for (const raw of readFileSync(file, 'utf8').split('\n')) {
    const line = raw.trim()
    if (!line || line.startsWith('#')) continue
    const eq = line.indexOf('=')
    if (eq === -1) continue
    out[line.slice(0, eq).trim()] = line.slice(eq + 1).trim().replace(/^["']|["']$/g, '')
  }
  return out
}

function tomlVar(name) {
  const toml = readFileSync(path.join(backendDir, 'wrangler.toml'), 'utf8')
  const m = toml.match(new RegExp(`^\\s*${name}\\s*=\\s*"([^"]*)"`, 'm'))
  return m ? m[1] : undefined
}

function parseArgs(argv) {
  const args = { ttl: 3600 }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--demo' || a === '--postman') args[a.slice(2)] = true
    else if (a.startsWith('--')) args[a.slice(2)] = argv[++i]
  }
  return args
}

function fail(msg) {
  console.error(msg)
  process.exit(1)
}

const args = parseArgs(process.argv.slice(2))
const devVars = parseDotEnv(path.join(backendDir, '.dev.vars'))
const secret = (args.secret ?? devVars.JWT_SECRET ?? '').trim()
const iss = args.iss ?? devVars.JWT_ISSUER ?? tomlVar('JWT_ISSUER')
const aud = args.aud ?? devVars.JWT_AUDIENCE ?? tomlVar('JWT_AUDIENCE')

if (Buffer.byteLength(secret) < 32 || secret === 'CHANGE_ME') {
  fail('JWT_SECRET is missing, a placeholder, or shorter than 32 bytes. Run `npm run setup:local` first.')
}
if (!iss || !aud) fail('JWT_ISSUER / JWT_AUDIENCE not found in wrangler.toml [vars] or .dev.vars.')

const DEMO_ACTORS = [
  { key: 'customer_a', sub: 'user123', role: 'CUSTOMER', note: 'customer with Discovery, Sanlam and Old Mutual policies' },
  { key: 'customer_b', sub: 'user456', role: 'CUSTOMER', note: 'customer with an OUTsurance policy, no claims' },
  { key: 'assessor_a', sub: 'assessor_a1', role: 'ASSESSOR', tenant: 'ins_discovery', note: 'tenant A (Discovery) staff' },
  { key: 'manager_a', sub: 'manager_a1', role: 'MANAGER', tenant: 'ins_discovery', note: 'tenant A (Discovery) manager' },
  { key: 'assessor_b', sub: 'assessor_b1', role: 'ASSESSOR', tenant: 'ins_sanlam', note: 'tenant B (Sanlam) staff' },
  { key: 'manager_b', sub: 'manager_b1', role: 'MANAGER', tenant: 'ins_sanlam', note: 'tenant B (Sanlam) manager' },
  { key: 'admin', sub: 'admin1', role: 'ADMIN', note: 'no claim access' },
]

function validate({ sub, role, tenant }, ttl) {
  if (!ID.test(sub ?? '')) fail(`--sub must match ${ID}`)
  if (!ROLES.includes(role)) fail(`--role must be one of ${ROLES.join(', ')}`)
  if (tenant !== undefined && !ID.test(tenant)) fail(`--tenant must match ${ID}`)
  if (role === 'CUSTOMER' && tenant) fail('CUSTOMER tokens must not carry a tenant')
  if ((role === 'ASSESSOR' || role === 'MANAGER') && !tenant) fail(`${role} tokens require --tenant`)
  // 60 s below the server maximum so a minting machine slightly ahead of the server still passes.
  if (!(ttl > 0) || ttl > MAX_TTL[role] - 60) fail(`--ttl must be between 1 and ${MAX_TTL[role] - 60} seconds for ${role}`)
}

async function mint(actor) {
  const ttl = Number(args.ttl)
  validate(actor, ttl)
  const now = Math.floor(Date.now() / 1000)
  // iat is backdated by 60 s so a laptop clock slightly ahead of the server does not trip
  // the server's strict issued-at check.
  const payload = { sub: actor.sub, role: actor.role, iss, aud, iat: now - 60, exp: now + ttl }
  if (actor.tenant) payload.tenant_id = actor.tenant
  return sign(payload, secret, 'HS256')
}

if (args.demo) {
  for (const actor of DEMO_ACTORS) {
    console.log(`# ${actor.sub} (${actor.role}${actor.tenant ? ', ' + actor.tenant : ''}) - ${actor.note}`)
    console.log(await mint(actor))
    console.log()
  }
} else if (args.postman) {
  const values = [
    { key: 'baseUrl', value: 'http://127.0.0.1:8787', enabled: true },
    { key: 'claimId', value: 'claim_disc_101', enabled: true },
  ]
  for (const actor of DEMO_ACTORS) values.push({ key: `token_${actor.key}`, value: await mint(actor), type: 'secret', enabled: true })
  const outDir = path.join(backendDir, 'postman')
  mkdirSync(outDir, { recursive: true })
  const outFile = path.join(outDir, 'EasyClaim.local.postman_environment.json')
  writeFileSync(outFile, JSON.stringify({ name: 'EasyClaim local (generated, do not commit)', values }, null, 2) + '\n')
  console.log(`Wrote ${path.relative(backendDir, outFile)} (tokens valid for ${args.ttl}s). Import it in Postman as an environment.`)
} else {
  if (!args.sub || !args.role) {
    fail('Usage: npm run token -- --sub <id> --role <CUSTOMER|ASSESSOR|MANAGER|ADMIN> [--tenant <id>] [--ttl 3600]')
  }
  console.log(await mint({ sub: args.sub, role: args.role, tenant: args.tenant }))
}
