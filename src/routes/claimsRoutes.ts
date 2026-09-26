import { Hono } from 'hono';
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
