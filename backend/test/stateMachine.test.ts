import { describe, expect, it } from 'vitest'
import { CLAIM_STAGES, TRANSITIONS, checkTransition } from '../src/security/claimStateMachine'

// Team role model (26 Sep 2026): the insurer side is one role, INSURER_ADMIN, that performs
// every insurer edge (verify, screen, review, request info, decide, pay, re-review appeal).
// SUPERADMIN has no claim edges at all.

describe('claim state machine (unit)', () => {
  it.each([
    ['Draft', 'Submitted', 'CUSTOMER'],
    ['Submitted', 'Verified', 'INSURER_ADMIN'],
    ['Verified', 'Screening', 'INSURER_ADMIN'],
    ['Screening', 'Review', 'INSURER_ADMIN'],
    ['Screening', 'Info Needed', 'INSURER_ADMIN'],
    ['Info Needed', 'Screening', 'CUSTOMER'],
    ['Review', 'Decision', 'INSURER_ADMIN'],
    ['Decision', 'Paid', 'INSURER_ADMIN'],
    ['Decision', 'Appeal', 'CUSTOMER'],
    ['Appeal', 'Review', 'INSURER_ADMIN'],
    ['Review', 'Withdrawn', 'CUSTOMER'],
    ['Info Needed', 'Expired', 'SYSTEM'],
  ] as const)('allows %s -> %s by %s', (from, to, actor) => {
    expect(checkTransition(from, to, actor)).toEqual({ ok: true })
  })

  it.each([
    ['Submitted', 'Paid', 'INSURER_ADMIN'],
    ['Screening', 'Paid', 'INSURER_ADMIN'],
    ['Submitted', 'Decision', 'INSURER_ADMIN'],
    ['Screening', 'Decision', 'INSURER_ADMIN'], // skipping review
    ['Verified', 'Review', 'INSURER_ADMIN'], // skipping screening
    ['Draft', 'Verified', 'CUSTOMER'],
    ['Paid', 'Review', 'INSURER_ADMIN'], // terminal
    ['Withdrawn', 'Submitted', 'CUSTOMER'], // terminal
  ] as const)('rejects illegal %s -> %s', (from, to, actor) => {
    expect(checkTransition(from, to, actor)).toEqual({ ok: false, reason: 'illegal_transition' })
  })

  it.each([
    ['Review', 'Decision', 'CUSTOMER'], // customer cannot decide
    ['Review', 'Decision', 'SUPERADMIN'], // platform operator never decides
    ['Decision', 'Paid', 'CUSTOMER'], // customer cannot pay out
    ['Decision', 'Paid', 'SUPERADMIN'], // platform operator never pays
    ['Submitted', 'Verified', 'CUSTOMER'],
    ['Submitted', 'Verified', 'SUPERADMIN'],
    ['Appeal', 'Review', 'SUPERADMIN'],
    ['Info Needed', 'Expired', 'CUSTOMER'],
  ] as const)('rejects %s -> %s by %s (role)', (from, to, actor) => {
    expect(checkTransition(from, to, actor)).toEqual({ ok: false, reason: 'role_not_permitted' })
  })

  it('rejects unknown stages', () => {
    expect(checkTransition('Approved', 'Paid', 'INSURER_ADMIN')).toEqual({ ok: false, reason: 'unknown_stage' })
    expect(checkTransition('Decision', 'PAID', 'INSURER_ADMIN')).toEqual({ ok: false, reason: 'unknown_stage' })
  })

  it('SUPERADMIN appears in no transition', () => {
    for (const from of CLAIM_STAGES) {
      for (const roles of Object.values(TRANSITIONS[from])) expect(roles).not.toContain('SUPERADMIN')
    }
  })

  it('the retired roles appear in no transition', () => {
    for (const from of CLAIM_STAGES) {
      for (const roles of Object.values(TRANSITIONS[from])) {
        expect(roles).not.toContain('ASSESSOR')
        expect(roles).not.toContain('MANAGER')
        expect(roles).not.toContain('ADMIN')
      }
    }
  })

  it('only INSURER_ADMIN can move a claim to Decision or Paid', () => {
    for (const from of CLAIM_STAGES) {
      for (const to of ['Decision', 'Paid'] as const) {
        const roles = TRANSITIONS[from][to]
        if (roles) expect(roles).toEqual(['INSURER_ADMIN'])
      }
    }
  })
})
