import { describe, expect, it } from 'vitest'
import { CLAIM_STAGES, TRANSITIONS, checkTransition } from '../src/security/claimStateMachine'

// Final role model (26 Sep 2026): ASSESSOR and MANAGER work claims; only a MANAGER decides, pays
// and re-opens an appeal (Phase 3 separation of duties). INSURER_ADMIN and SUPERADMIN administer
// accounts and never move a claim.

describe('claim state machine (unit)', () => {
  it.each([
    ['Draft', 'Submitted', 'CUSTOMER'],
    ['Submitted', 'Verified', 'ASSESSOR'],
    ['Submitted', 'Verified', 'MANAGER'],
    ['Verified', 'Screening', 'ASSESSOR'],
    ['Screening', 'Review', 'ASSESSOR'],
    ['Screening', 'Info Needed', 'ASSESSOR'],
    ['Review', 'Info Needed', 'MANAGER'],
    ['Info Needed', 'Screening', 'CUSTOMER'],
    ['Review', 'Decision', 'MANAGER'],
    ['Decision', 'Paid', 'MANAGER'],
    ['Decision', 'Appeal', 'CUSTOMER'],
    ['Appeal', 'Review', 'MANAGER'],
    ['Review', 'Withdrawn', 'CUSTOMER'],
    ['Info Needed', 'Expired', 'SYSTEM'],
  ] as const)('allows %s -> %s by %s', (from, to, actor) => {
    expect(checkTransition(from, to, actor)).toEqual({ ok: true })
  })

  it.each([
    ['Submitted', 'Paid', 'MANAGER'],
    ['Screening', 'Paid', 'MANAGER'],
    ['Submitted', 'Decision', 'MANAGER'],
    ['Screening', 'Decision', 'MANAGER'], // skipping review
    ['Verified', 'Review', 'ASSESSOR'], // skipping screening
    ['Draft', 'Verified', 'CUSTOMER'],
    ['Paid', 'Review', 'MANAGER'], // terminal
    ['Withdrawn', 'Submitted', 'CUSTOMER'], // terminal
  ] as const)('rejects illegal %s -> %s', (from, to, actor) => {
    expect(checkTransition(from, to, actor)).toEqual({ ok: false, reason: 'illegal_transition' })
  })

  it.each([
    ['Review', 'Decision', 'ASSESSOR'], // separation of duties
    ['Decision', 'Paid', 'ASSESSOR'],
    ['Appeal', 'Review', 'ASSESSOR'],
    ['Review', 'Decision', 'CUSTOMER'],
    ['Decision', 'Paid', 'CUSTOMER'],
    ['Review', 'Decision', 'INSURER_ADMIN'], // administers accounts, never claims
    ['Decision', 'Paid', 'INSURER_ADMIN'],
    ['Submitted', 'Verified', 'INSURER_ADMIN'],
    ['Review', 'Decision', 'SUPERADMIN'],
    ['Decision', 'Paid', 'SUPERADMIN'],
    ['Submitted', 'Verified', 'SUPERADMIN'],
    ['Appeal', 'Review', 'SUPERADMIN'],
    ['Submitted', 'Verified', 'CUSTOMER'],
    ['Info Needed', 'Expired', 'CUSTOMER'],
    ['Info Needed', 'Expired', 'MANAGER'],
  ] as const)('rejects %s -> %s by %s (role)', (from, to, actor) => {
    expect(checkTransition(from, to, actor)).toEqual({ ok: false, reason: 'role_not_permitted' })
  })

  it('rejects unknown stages', () => {
    expect(checkTransition('Approved', 'Paid', 'MANAGER')).toEqual({ ok: false, reason: 'unknown_stage' })
    expect(checkTransition('Decision', 'PAID', 'MANAGER')).toEqual({ ok: false, reason: 'unknown_stage' })
  })

  it('INSURER_ADMIN, SUPERADMIN and the retired ADMIN appear in no transition', () => {
    for (const from of CLAIM_STAGES) {
      for (const roles of Object.values(TRANSITIONS[from])) {
        expect(roles).not.toContain('INSURER_ADMIN')
        expect(roles).not.toContain('SUPERADMIN')
        expect(roles).not.toContain('ADMIN')
      }
    }
  })

  it('only MANAGER can move a claim to Decision or Paid, or re-open an appeal', () => {
    for (const from of CLAIM_STAGES) {
      for (const to of ['Decision', 'Paid'] as const) {
        const roles = TRANSITIONS[from][to]
        if (roles) expect(roles).toEqual(['MANAGER'])
      }
    }
    expect(TRANSITIONS.Appeal.Review).toEqual(['MANAGER'])
  })
})
