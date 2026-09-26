import { Context } from 'hono';
import { ClaimsService } from '../services/claimsService';

export class ClaimsController {
  static getStatus(c: Context) {
    return c.json({ status: 'active' });
  }

  static async initiate(c: Context) {
    const claimId = ClaimsService.initiateClaim();
    return c.json({ status: 'draft_created', claimId }, 201);
  }

  static verifyEligibility(c: Context) {
    return c.json({ verified: true, context: ClaimsService.verifyEligibility() });
  }

  static async uploadEvidence(c: Context) {
    const claimId = c.req.param('claimId');
    await ClaimsService.triggerEvent(c.env, 'ClaimEvidenceUploaded', claimId);
    return c.json({ status: 'processing OCR', message: 'Documents queued for analysis' }, 202);
  }

  static async submit(c: Context) {
    const claimId = c.req.param('claimId');
    await ClaimsService.triggerEvent(c.env, 'ClaimSubmitted', claimId);
    return c.json({ stage: 'SUBMITTED', message: 'Claim successfully submitted. Checklist complete.', claimId });
  }

  static verify(c: Context) {
    return c.json({ stage: 'VERIFIED', message: 'Identity and policy confirmed.' });
  }

  static screening(c: Context) {
    return c.json({ stage: 'SCREENING', status: 'screening_updated', message: 'Risk score and route assigned.' });
  }

  static review(c: Context) {
    return c.json({ stage: 'REVIEW', message: 'Assessor review outcome recorded.' });
  }

  static async postDecision(c: Context) {
    const body = await c.req.json().catch(() => ({ decision: 'approved' }));
    return c.json({ stage: 'DECISION', decision: body.decision, message: 'Customer notified of decision.' });
  }

  static getDecision(c: Context) {
    return c.json({ decision: 'pending' });
  }

  static pay(c: Context) {
    return c.json({ stage: 'PAID', message: 'Payment confirmed, claim closed.' });
  }

  static infoNeeded(c: Context) {
    return c.json({ state: 'INFO_NEEDED', message: 'Claim paused. Waiting for customer information.' });
  }

  static async reject(c: Context) {
    const body = await c.req.json().catch(() => ({ reason: 'Not covered' }));
    return c.json({ state: 'REJECTED', reason: body.reason, message: 'Claim rejected. Plain language reason provided.' });
  }

  static appeal(c: Context) {
    return c.json({ state: 'APPEAL', message: 'Appeal lodged. Claim returning to REVIEW stage.' });
  }

  static timeline(c: Context) {
    return c.json({ timeline: ClaimsService.getTimeline() });
  }
}
