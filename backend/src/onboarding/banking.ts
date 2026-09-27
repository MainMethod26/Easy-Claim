/**
 * Customer banking details (Profile › Banking details, migrations/0017_customer_banking.sql).
 *
 * One payout account per customer. Claims no longer ask for it: on submission the profile account is
 * copied onto the claim, and a decision freezes that destination (see claimsInsurer.ts / ledger.ts).
 * The full account number is hashed and never stored or returned.
 */
import type { Context } from 'hono'
import type { AppEnv } from '../types'
import { auditStatement } from '../security/audit'
import { destinationHash } from '../security/ledger'

type C = Context<AppEnv>

interface BankingRow {
  user_id: string
  bank_name: string
  account_holder: string
  account_last4: string
  destination_hash: string
  updated_at: string
}

export interface BankingDto {
  bankName: string
  accountHolder: string
  accountLast4: string
  updatedAt: string
}

const toDto = (r: BankingRow): BankingDto => ({
  bankName: r.bank_name,
  accountHolder: r.account_holder,
  accountLast4: r.account_last4,
  updatedAt: r.updated_at,
})

export async function loadBanking(db: D1Database, userId: string): Promise<BankingRow | null> {
  return db.prepare('SELECT * FROM customer_banking WHERE user_id = ?').bind(userId).first<BankingRow>()
}

export async function getMyBanking(c: C): Promise<{ banking: BankingDto | null }> {
  const row = await loadBanking(c.env.DB, c.get('actor').id)
  return { banking: row ? toDto(row) : null }
}

export async function saveMyBanking(c: C, input: { bankName: string; accountHolder: string; accountNumber: string }): Promise<{ banking: BankingDto }> {
  const actor = c.get('actor')
  const bankName = input.bankName.trim()
  const accountHolder = input.accountHolder.trim()
  const hash = await destinationHash(bankName, input.accountNumber)
  const at = new Date().toISOString()
  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO customer_banking (user_id, bank_name, account_holder, account_last4, destination_hash, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET bank_name = excluded.bank_name, account_holder = excluded.account_holder,
         account_last4 = excluded.account_last4, destination_hash = excluded.destination_hash, updated_at = excluded.updated_at`
    ).bind(actor.id, bankName, accountHolder, input.accountNumber.slice(-4), hash, at),
    // Never the account itself: only that it changed.
    auditStatement(c, { action: 'customer.banking_saved', resourceType: 'user', resourceId: actor.id, outcome: 'success' }),
  ])
  return { banking: toDto((await loadBanking(c.env.DB, actor.id)) as BankingRow) }
}

/**
 * Copies the customer's profile account onto a claim that has no payout destination yet. Only claims the
 * customer can still edit (Draft / Info Needed) or that are awaiting a decision are touched, and never one
 * that already has a destination, so a decided destination can never change. Returns true when copied.
 */
export async function applyProfileBanking(db: D1Database, claimId: string, userId: string): Promise<boolean> {
  const row = await loadBanking(db, userId)
  if (!row) return false
  const at = new Date().toISOString()
  const r = await db
    .prepare(
      `UPDATE claims SET payout_bank_name = ?, payout_account_holder = ?, payout_account_last4 = ?, payout_destination_hash = ?,
         payout_details_updated_at = ?
       WHERE id = ? AND user_id = ? AND payout_destination_hash IS NULL
         AND stage IN ('Draft', 'Info Needed', 'Submitted', 'Verified', 'Screening', 'Review')`
    )
    .bind(row.bank_name, row.account_holder, row.account_last4, row.destination_hash, at, claimId, userId)
    .run()
  return r.meta.changes === 1
}
