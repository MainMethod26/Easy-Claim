import { describe, expect, it } from 'vitest'
import { CLAIM_STAGES, TRANSITIONS, checkTransition } from '../src/security/claimStateMachine'

describe('claim state machine (unit)', () => {
  it.each([
    ['Draft', 'Submitted', 'CUSTOMER'],
    ['Submitted', 'Verified', 'ASSESSOR'],
    ['Verified', 'Screening', 'ASSESSOR'],
    ['Screening', 'Review', 'ASSESSOR'],
    ['Screening', 'Info Needed', 'ASSESSOR'],
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
    ['Submitted', 'Decision', 'ASSESSOR'],
    ['Screening', 'Decision', 'ASSESSOR'], // skipping review
    ['Verified', 'Review', 'ASSESSOR'], // skipping screening
    ['Draft', 'Verified', 'CUSTOMER'],
    ['Paid', 'Review', 'MANAGER'], // terminal
    ['Withdrawn', 'Submitted', 'CUSTOMER'], // terminal
  ] as const)('rejects illegal %s -> %s', (from, to, actor) => {
    expect(checkTransition(from, to, actor)).toEqual({ ok: false, reason: 'illegal_transition' })
  })

  it.each([
    ['Review', 'Decision', 'CUSTOMER'], // customer cannot decide
    ['Decision', 'Paid', 'CUSTOMER'], // customer cannot pay out
    ['Decision', 'Paid', 'ASSESSOR'], // payout is manager-only
    ['Submitted', 'Verified', 'CUSTOMER'],
    ['Review', 'Decision', 'ADMIN'], // admin has no claim powers
    ['Decision', 'Paid', 'ADMIN'],
    ['Info Needed', 'Expired', 'CUSTOMER'],
  ] as const)('rejects %s -> %s by %s (role)', (from, to, actor) => {
    expect(checkTransition(from, to, actor)).toEqual({ ok: false, reason: 'role_not_permitted' })
  })

  it('rejects unknown stages', () => {
    expect(checkTransition('Approved', 'Paid', 'MANAGER')).toEqual({ ok: false, reason: 'unknown_stage' })
    expect(checkTransition('Decision', 'PAID', 'MANAGER')).toEqual({ ok: false, reason: 'unknown_stage' })
  })

  it('ADMIN appears in no transition', () => {
    for (const from of CLAIM_STAGES) {
      for (const roles of Object.values(TRANSITIONS[from])) expect(roles).not.toContain('ADMIN')
    }
  })

  it('only MANAGER can move a claim to Paid', () => {
    for (const from of CLAIM_STAGES) {
      const roles = TRANSITIONS[from].Paid
      if (roles) expect(roles).toEqual(['MANAGER'])
    }
  })
})
