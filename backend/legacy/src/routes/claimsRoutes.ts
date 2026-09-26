import { Hono } from 'hono';
import { Env } from '../types/env';
import { ClaimsController } from '../controllers/claimsController';

const router = new Hono<{ Bindings: Env }>();


router.get('/status', ClaimsController.getStatus);
router.post('/initiate', ClaimsController.initiate);
router.get('/eligibility', ClaimsController.verifyEligibility);
router.post('/:claimId/evidence', ClaimsController.uploadEvidence);
router.post('/:claimId/submit', ClaimsController.submit);
router.get('/:claimId/verify', ClaimsController.verify);
router.get('/:claimId/screening', ClaimsController.screening);
router.get('/:claimId/review', ClaimsController.review);
router.post('/:claimId/decision', ClaimsController.postDecision);
router.get('/:claimId/decision', ClaimsController.getDecision);
router.post('/:claimId/pay', ClaimsController.pay);
router.post('/:claimId/info-needed', ClaimsController.infoNeeded);
router.post('/:claimId/reject', ClaimsController.reject);
router.post('/:claimId/appeal', ClaimsController.appeal);
router.get('/:claimId/timeline', ClaimsController.timeline);


export default router;
