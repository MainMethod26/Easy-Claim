import { Context } from 'hono';
import { ClaimsService } from '../services/claimsService';

export class ClaimsController {
  static getStatus(c: Context) {
    return c.json({ status: 'active' });
  }

  static async initiate(c: Context) {
    const userId = c.req.header('x-user-id') || 'user123';
    const body = await c.req.json().catch(() => ({}));
    const claimId = await ClaimsService.initiateClaim(c.env.DB, userId, body.policyId || 'pol_123');
    return c.json({ status: 'draft_created', claimId }, 201);
  }

  static async verifyEligibility(c: Context) {
    const result = await ClaimsService.verifyEligibility(c.env.DB);
    return c.json({ verified: true, context: result });
  }

  static async uploadEvidence(c: Context) {
    const claimId = c.req.param('claimId') || '';
    await ClaimsService.triggerEvent(c.env, 'ClaimEvidenceUploaded', claimId);
    return c.json({ status: 'processing OCR', message: 'Documents queued for analysis' }, 202);
  }

  static async submit(c: Context) {
    const claimId = c.req.param('claimId') || '';
    await ClaimsService.updateStage(c.env.DB, claimId, 'SUBMITTED');
    await ClaimsService.triggerEvent(c.env, 'ClaimSubmitted', claimId);
    return c.json({ stage: 'SUBMITTED', message: 'Claim successfully submitted. Checklist complete.', claimId });
  }

  static async verify(c: Context) {
    const claimId = c.req.param('claimId') || '';
    await ClaimsService.updateStage(c.env.DB, claimId, 'VERIFIED');
    return c.json({ stage: 'VERIFIED', message: 'Identity and policy confirmed.' });
  }

  static async screening(c: Context) {
    const claimId = c.req.param('claimId') || '';
    await ClaimsService.updateStage(c.env.DB, claimId, 'SCREENING');
    return c.json({ stage: 'SCREENING', status: 'screening_updated', message: 'Risk score and route assigned.' });
  }

  static async review(c: Context) {
    const claimId = c.req.param('claimId') || '';
    await ClaimsService.updateStage(c.env.DB, claimId, 'REVIEW');
    return c.json({ stage: 'REVIEW', message: 'Assessor review outcome recorded.' });
  }

  static async postDecision(c: Context) {
    const claimId = c.req.param('claimId') || '';
    const body = await c.req.json().catch(() => ({ decision: 'approved', reason: 'Looks good' }));
    await ClaimsService.setDecision(c.env.DB, claimId, body.decision === 'approved' ? 'DECISION' : 'REJECTED', body.reason);
    return c.json({ stage: 'DECISION', decision: body.decision, message: 'Customer notified of decision.' });
  }

  static async getDecision(c: Context) {
    const claimId = c.req.param('claimId') || '';
    const claim = await ClaimsService.getClaim(c.env.DB, claimId);
    return c.json({ decision: claim ? claim.decision_reason : 'pending' });
  }

  static async pay(c: Context) {
    const claimId = c.req.param('claimId') || '';
    await ClaimsService.updateStage(c.env.DB, claimId, 'PAID');
    return c.json({ stage: 'PAID', message: 'Payment confirmed, claim closed.' });
  }

  static async infoNeeded(c: Context) {
    const claimId = c.req.param('claimId') || '';
    await ClaimsService.updateStage(c.env.DB, claimId, 'INFO_NEEDED');
    return c.json({ state: 'INFO_NEEDED', message: 'Claim paused. Waiting for customer information.' });
  }

  static async reject(c: Context) {
    const claimId = c.req.param('claimId') || '';
    const body = await c.req.json().catch(() => ({ reason: 'Not covered' }));
    await ClaimsService.setDecision(c.env.DB, claimId, 'REJECTED', body.reason);
    return c.json({ state: 'REJECTED', reason: body.reason, message: 'Claim rejected. Plain language reason provided.' });
  }

  static async appeal(c: Context) {
    const claimId = c.req.param('claimId') || '';
    await ClaimsService.updateStage(c.env.DB, claimId, 'APPEAL');
    return c.json({ state: 'APPEAL', message: 'Appeal lodged. Claim returning to REVIEW stage.' });
  }

  static async timeline(c: Context) {
    const claimId = c.req.param('claimId') || '';
    const timeline = await ClaimsService.getTimeline(c.env.DB, claimId);
    return c.json({ timeline });
  }
}
