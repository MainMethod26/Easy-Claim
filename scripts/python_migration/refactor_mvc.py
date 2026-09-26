import os
import re

endpoints_dir = "backend/src/endpoints"
controllers_dir = "backend/src/controllers"
services_dir = "backend/src/services"
routes_dir = "backend/src/routes"

# We'll just manually write out the new files because parsing AST in Python is too hard.

# 1. Audit
audit_service = """export class AuditService {
  static getHistory() {
    return [
      { id: 'act_01', date: '2023-10-15T10:30:00Z', action: 'Uploaded hospital invoice for Discovery Health claim.' },
      { id: 'act_02', date: '2023-10-10T14:15:00Z', action: 'Canceled debit order mandate for OUTsurance.' },
      { id: 'act_03', date: '2023-09-01T09:00:00Z', action: 'Joined Sanlam Comprehensive Life Cover.' }
    ];
  }

  static getAuditTrail() {
    return [
      { event: 'LOGIN_SUCCESS', ip: '197.85.12.34', location: 'Johannesburg, ZA', timestamp: '2023-10-16T08:00:00Z' },
      { event: 'DOCUMENT_UPLOAD', ip: '197.85.12.34', location: 'Johannesburg, ZA', timestamp: '2023-10-15T10:30:00Z' },
      { event: 'CONSENT_GRANTED', ip: '197.85.12.34', location: 'Johannesburg, ZA', timestamp: '2023-06-22T11:45:00Z' }
    ];
  }
}
"""

audit_controller = """import { Context } from 'hono';
import { AuditService } from '../services/auditService';

export class AuditController {
  static getHistory(c: Context) {
    const history = AuditService.getHistory();
    return c.json({ history });
  }

  static getAuditTrail(c: Context) {
    const trail = AuditService.getAuditTrail();
    return c.json({ trail });
  }
}
"""

audit_routes = """import { Hono } from 'hono';
import { AuditController } from '../controllers/auditController';

const router = new Hono();

router.get('/history', AuditController.getHistory);
router.get('/audit-trail', AuditController.getAuditTrail);

export default router;
"""

# 2. OCR
ocr_service = """export class OcrService {
  static processDocument() {
    return { extracted: true };
  }
}
"""

ocr_controller = """import { Context } from 'hono';
import { OcrService } from '../services/ocrService';

export class OcrController {
  static process(c: Context) {
    const result = OcrService.processDocument();
    return c.json(result);
  }
}
"""

ocr_routes = """import { Hono } from 'hono';
import { OcrController } from '../controllers/ocrController';

const router = new Hono();

router.post('/process', OcrController.process);

export default router;
"""

# 3. Gateway
gateway_service = """export class GatewayService {
  static getHomeData() {
    return { 
      message: 'Welcome to EasyClaim SA',
      alerts: [
        "Your OUTsurance claim #claim_out_101 is being reviewed.",
        "Discovery Health updated their claim submission guidelines."
      ]
    };
  }
  
  static getMostVisitedServices() {
    return [
      { service: 'Submit Medical Claim (Discovery)' },
      { service: 'View Life Policy (Sanlam)' },
      { service: 'Log Car Accident (OUTsurance)' }
    ];
  }
  
  static getNotifications() {
    return [
      { type: 'Update', message: 'Momentum Health approved your recent pharmacy claim.' },
      { type: 'Reminder', message: 'Old Mutual premium of R150 is due on the 1st.' }
    ];
  }
  
  static getRecentActivity() {
    return [
      { date: '2023-10-15', action: 'Uploaded hospital invoice for Discovery Health.' },
      { date: '2023-10-10', action: 'Canceled mandate for old insurance provider.' }
    ];
  }
}
"""

gateway_controller = """import { Context } from 'hono';
import { GatewayService } from '../services/gatewayService';

export class GatewayController {
  static getHome(c: Context) {
    return c.json(GatewayService.getHomeData());
  }

  static getMostVisited(c: Context) {
    return c.json({ data: GatewayService.getMostVisitedServices() });
  }

  static getNotifications(c: Context) {
    return c.json({ notifications: GatewayService.getNotifications() });
  }

  static getRecentActivity(c: Context) {
    return c.json({ activity: GatewayService.getRecentActivity() });
  }
}
"""

gateway_routes = """import { Hono } from 'hono';
import { GatewayController } from '../controllers/gatewayController';

const router = new Hono();

router.get('/home', GatewayController.getHome);
router.get('/services/most-visited', GatewayController.getMostVisited);
router.get('/notifications', GatewayController.getNotifications);
router.get('/activity/recent', GatewayController.getRecentActivity);

export default router;
"""

# 4. Identity
identity_service = """export class IdentityService {
  static getProfile(userId: string) {
    return {
      id: userId,
      firstName: 'Sipho',
      lastName: 'Nkosi',
      idNumber: '8505125021087',
      email: 'sipho.nkosi@example.co.za',
      phone: '+27 82 123 4567',
      address: '123 Nelson Mandela Drive, Sandton, 2196',
      riskProfile: 'Low',
      kycStatus: 'Verified'
    };
  }

  static updateProfile(data: any) {
    return data;
  }

  static getConsents() {
    return [
      { id: 'c_popia', name: 'POPIA Data Processing', status: 'Granted', date: '2023-01-15' },
      { id: 'c_marketing', name: 'Marketing Communications', status: 'Declined', date: '2023-01-15' },
      { id: 'c_medical', name: 'Medical Records Sharing (Discovery)', status: 'Granted', date: '2023-06-22' }
    ];
  }

  static checkMandate(tenantId: string) {
    return { 
      tenantId: tenantId,
      mandateActive: true,
      amount: 'R 850.00',
      nextDeduction: '2023-11-01',
      bankName: 'Standard Bank',
      accountEnding: '4567'
    };
  }
  
  static cancelMandate() {
    return { 
      status: 'success',
      message: 'Debit order mandate successfully cancelled.',
      cancellationDate: new Date().toISOString()
    };
  }

  static login(idNumber: string) {
    if (idNumber === '8505125021087') {
      return {
        status: 'success',
        message: 'Login successful',
        token: 'mock-jwt-token-123',
        profile: this.getProfile('user123')
      };
    }
    return null;
  }
}
"""

identity_controller = """import { Context } from 'hono';
import { IdentityService } from '../services/identityService';

export class IdentityController {
  static getProfile(c: Context) {
    return c.json({ profile: IdentityService.getProfile('user123') });
  }

  static async updateProfile(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const updatedFields = IdentityService.updateProfile(body);
    return c.json({ 
      status: 'success', 
      message: 'Profile updated successfully',
      updatedFields
    });
  }

  static getConsents(c: Context) {
    return c.json({ consents: IdentityService.getConsents() });
  }

  static checkMandate(c: Context) {
    const tenantId = c.req.param('tenantId');
    return c.json(IdentityService.checkMandate(tenantId));
  }

  static async cancelMandate(c: Context) {
    return c.json(IdentityService.cancelMandate());
  }

  static async login(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const result = IdentityService.login(body.idNumber);
    
    if (result) {
      return c.json(result);
    }
    return c.json({ status: 'error', message: 'Invalid SA ID number' }, 401);
  }
}
"""

identity_routes = """import { Hono } from 'hono';
import { IdentityController } from '../controllers/identityController';

const router = new Hono();

router.get('/', IdentityController.getProfile);
router.patch('/', IdentityController.updateProfile);
router.get('/consent', IdentityController.getConsents);
router.get('/mandates/:tenantId/check', IdentityController.checkMandate);
router.post('/mandates/cancel', IdentityController.cancelMandate);
router.post('/login', IdentityController.login);

export default router;
"""

# 5. Policy
policy_service = """import { PolicyModel } from '../models/policyModel';

export class PolicyService {
  static async getMyCovers(db: any, userId: string) {
    return await PolicyModel.getMyCovers(db, userId);
  }

  static getMarketCatalog() {
    return [
      { id: 'cat_01', provider: 'Discovery Health', name: 'Smart Plan', premium: 'R 2,450 / month' },
      { id: 'cat_02', provider: 'Sanlam', name: 'Comprehensive Life Cover', premium: 'R 850 / month' },
      { id: 'cat_03', provider: 'OUTsurance', name: 'Home & Contents Cover', premium: 'R 1,100 / month' },
      { id: 'cat_04', provider: 'Momentum', name: 'Ingwe Network Health', premium: 'R 540 / month' },
      { id: 'cat_05', provider: 'Old Mutual', name: 'Protect Family Funeral Plan', premium: 'R 150 / month' }
    ];
  }

  static processRequirements(body: any) {
    const insuranceType = body.insurance_type;
    let capturedData: any = {};
    
    if (insuranceType === 'Mobile Device Insurance') {
      capturedData = {
        insurance_type: body.insurance_type,
        jurisdiction: body.jurisdiction || 'South Africa',
        regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA'],
        customer_identity_kyc: body.customer_identity_kyc,
        asset_specific_details: body.asset_specific_details,
        risk_and_underwriting: body.risk_and_underwriting,
        financial_and_settlement: body.financial_and_settlement
      };
    } else if (insuranceType === 'Home Insurance (Building Structure & Contents)') {
      capturedData = {
        insurance_type: body.insurance_type,
        jurisdiction: body.jurisdiction || 'South Africa',
        regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA', 'Short-Term Insurance Act'],
        customer_identity_kyc: body.customer_identity_kyc,
        property_and_asset_details: body.property_and_asset_details,
        risk_and_compliance: body.risk_and_compliance,
        financial_and_settlement: body.financial_and_settlement
      };
    } else if (insuranceType === 'Motor Vehicle Insurance') {
      capturedData = {
        insurance_type: body.insurance_type,
        jurisdiction: body.jurisdiction || 'South Africa',
        regulatory_framework: body.regulatory_framework || ['FICA', 'POPIA', 'National Road Traffic Act'],
        customer_identity_kyc: body.customer_identity_kyc,
        asset_specific_details: body.asset_specific_details,
        risk_and_underwriting: body.risk_and_underwriting,
        legal_and_consent: body.legal_and_consent
      };
    } else {
      return null;
    }
    
    return capturedData;
  }
}
"""

policy_controller = """import { Context } from 'hono';
import { PolicyService } from '../services/policyService';

export class PolicyController {
  static async getMyCovers(c: Context) {
    const db = (c.env as any).DB;
    const policies = await PolicyService.getMyCovers(db, 'user123');
    return c.json({ policies });
  }

  static getMarketCatalog(c: Context) {
    return c.json({ catalog: PolicyService.getMarketCatalog() });
  }

  static async joinRequest(c: Context) {
    const body = await c.req.json();
    return c.json({ status: 'Requested', message: 'Join request forwarded to provider.', body });
  }

  static async saveRequirements(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const capturedData = PolicyService.processRequirements(body);
    
    if (!capturedData) {
      return c.json({ status: 'error', message: 'Unknown insurance type' }, 400);
    }

    return c.json({ 
      status: 'success', 
      message: `${body.insurance_type} requirements saved successfully.`, 
      data: capturedData,
      artifacts: {
        policySchedule: 'generated',
        certificateOfInsurance: 'generated',
        policyContract: 'generated'
      }
    });
  }
}
"""

policy_routes = """import { Hono } from 'hono';
import { PolicyController } from '../controllers/policyController';

const router = new Hono();

router.get('/my-covers', PolicyController.getMyCovers);
router.get('/market-catalog', PolicyController.getMarketCatalog);
router.post('/join-request', PolicyController.joinRequest);
router.post('/requirements', PolicyController.saveRequirements);

export default router;
"""


# 6. Claims
claims_service = """export class ClaimsService {
  static initiateClaim() {
    return `claim_${Date.now()}`;
  }

  static verifyEligibility() {
    return { isIdentityValid: true, isPolicyActive: true, waitingPeriodCleared: true };
  }

  static async triggerEvent(env: any, eventName: string, claimId: string) {
    if (env.CLAIM_EVENTS) {
      await env.CLAIM_EVENTS.send({ event: eventName, data: { claimId, timestamp: new Date().toISOString() } });
    }
  }

  static getTimeline() {
    return [
      { stage: 'SUBMITTED', date: new Date().toISOString(), completed: true },
      { stage: 'VERIFIED', date: new Date().toISOString(), completed: true },
      { stage: 'SCREENING', date: new Date().toISOString(), completed: true },
      { stage: 'REVIEW', date: null, completed: false },
      { stage: 'DECISION', date: null, completed: false },
      { stage: 'PAID', date: null, completed: false }
    ];
  }
}
"""

claims_controller = """import { Context } from 'hono';
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
"""

claims_routes = """import { Hono } from 'hono';
import { ClaimsController } from '../controllers/claimsController';

const router = new Hono();

router.get('/status', ClaimsController.getStatus);
router.post('/initiate', ClaimsController.initiate);
router.post('/verify-eligibility', ClaimsController.verifyEligibility);
router.post('/:claimId/evidence-ocr', ClaimsController.uploadEvidence);
router.post('/:claimId/submit', ClaimsController.submit);
router.post('/:claimId/verify', ClaimsController.verify);
router.patch('/:claimId/screening', ClaimsController.screening);
router.post('/:claimId/review', ClaimsController.review);
router.post('/:claimId/decision', ClaimsController.postDecision);
router.get('/:claimId/decision', ClaimsController.getDecision);
router.post('/:claimId/pay', ClaimsController.pay);
router.post('/:claimId/info-needed', ClaimsController.infoNeeded);
router.post('/:claimId/reject', ClaimsController.reject);
router.post('/:claimId/appeal', ClaimsController.appeal);
router.get('/:claimId/timeline', ClaimsController.timeline);

export default router;
"""

import os

def write_file(path, content):
    with open(path, 'w') as f:
        f.write(content)

# Write out everything
write_file(f'{services_dir}/auditService.ts', audit_service)
write_file(f'{controllers_dir}/auditController.ts', audit_controller)
write_file(f'{routes_dir}/auditRoutes.ts', audit_routes)

write_file(f'{services_dir}/ocrService.ts', ocr_service)
write_file(f'{controllers_dir}/ocrController.ts', ocr_controller)
write_file(f'{routes_dir}/ocrRoutes.ts', ocr_routes)

write_file(f'{services_dir}/gatewayService.ts', gateway_service)
write_file(f'{controllers_dir}/gatewayController.ts', gateway_controller)
write_file(f'{routes_dir}/gatewayRoutes.ts', gateway_routes)

write_file(f'{services_dir}/identityService.ts', identity_service)
write_file(f'{controllers_dir}/identityController.ts', identity_controller)
write_file(f'{routes_dir}/identityRoutes.ts', identity_routes)

write_file(f'{services_dir}/policyService.ts', policy_service)
write_file(f'{controllers_dir}/policyController.ts', policy_controller)
write_file(f'{routes_dir}/policyRoutes.ts', policy_routes)

write_file(f'{services_dir}/claimsService.ts', claims_service)
write_file(f'{controllers_dir}/claimsController.ts', claims_controller)
write_file(f'{routes_dir}/claimsRoutes.ts', claims_routes)

