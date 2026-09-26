#!/usr/bin/env node
// Creates backend/.dev.vars from .dev.vars.example with a freshly generated JWT_SECRET.
// Never overwrites an existing .dev.vars.
import { randomBytes } from 'node:crypto'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const backendDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const target = path.join(backendDir, '.dev.vars')

if (existsSync(target)) {
  console.log('.dev.vars already exists; leaving it untouched.')
  process.exit(0)
}

const example = readFileSync(path.join(backendDir, '.dev.vars.example'), 'utf8')
const secret = randomBytes(32).toString('hex')
writeFileSync(
  target,
  example
    .replace(/^JWT_SECRET=.*$/m, `JWT_SECRET=${secret}`)
    .replace(/^MLDSA_SEED=.*$/m, `MLDSA_SEED=${randomBytes(32).toString('hex')}`)
)
console.log('Created .dev.vars with a new JWT_SECRET and MLDSA_SEED (local only, gitignored).')
console.log('Mint demo tokens with: npm run token -- --demo')
