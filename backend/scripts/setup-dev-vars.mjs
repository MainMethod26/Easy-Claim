#!/usr/bin/env node
// Creates backend/.dev.vars from .dev.vars.example with freshly generated local secrets:
// JWT_SECRET, MLDSA_SEED and DEMO_LOGIN_PASSWORD. Never overwrites an existing .dev.vars;
// with --add-missing it appends only the keys an older .dev.vars is missing.
// Secret values are written to the file only; they are never printed.
import { randomBytes } from 'node:crypto'
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const backendDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const target = path.join(backendDir, '.dev.vars')
const example = readFileSync(path.join(backendDir, '.dev.vars.example'), 'utf8')

// The agreed demo password for the seeded demo accounts (local only; see scripts/seed-demo-users.mjs).
const demoPassword = () => '1234567'

const generated = {
  JWT_SECRET: () => randomBytes(32).toString('hex'),
  MLDSA_SEED: () => randomBytes(32).toString('hex'),
  PII_KEY: () => randomBytes(32).toString('hex'),
  DEMO_LOGIN_PASSWORD: demoPassword,
}

if (existsSync(target)) {
  if (!process.argv.includes('--add-missing')) {
    console.log('.dev.vars already exists; leaving it untouched. Use `npm run setup:local -- --add-missing` to add new keys.')
    process.exit(0)
  }
  const current = readFileSync(target, 'utf8')
  const has = (k) => new RegExp(`^${k}=(?!CHANGE_ME\s*$).+`, 'm').test(current)
  const added = []
  for (const [key, make] of Object.entries(generated)) {
    if (!has(key)) {
      appendFileSync(target, `\n${key}=${make()}\n`)
      added.push(key)
    }
  }
  if (!/^ENVIRONMENT=/m.test(current)) {
    appendFileSync(target, '\nENVIRONMENT=development\n')
    added.push('ENVIRONMENT')
  }
  console.log(added.length ? `Added to .dev.vars: ${added.join(', ')} (values not shown).` : '.dev.vars already has every key.')
  process.exit(0)
}

let content = example
for (const [key, make] of Object.entries(generated)) {
  content = content.replace(new RegExp(`^${key}=.*$`, 'm'), `${key}=${make()}`)
}
writeFileSync(target, content)
console.log('Created .dev.vars with new JWT_SECRET, MLDSA_SEED, PII_KEY and DEMO_LOGIN_PASSWORD (local only, gitignored; values not shown).')
console.log('The demo login password is the DEMO_LOGIN_PASSWORD line in backend/.dev.vars.')
console.log('Mint offline tokens with: npm run token -- --demo')
