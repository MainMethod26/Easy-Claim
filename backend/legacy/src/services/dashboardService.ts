export class DashboardService {
  static async getDashboardData(db: any, userId: string) {
    // 0. Fetch real user
    const { results: userResults } = await db.prepare('SELECT first_name FROM users WHERE id = ?').bind(userId).all();
    const userName = userResults.length > 0 ? userResults[0].first_name : 'User';

    // 1. Fetch user claims
    const { results: claims } = await db.prepare('SELECT c.*, p.insurance_type as title, p.provider as provider, p.plan_name as planName FROM claims c JOIN policies p ON c.policy_id = p.id WHERE c.user_id = ? ORDER BY c.updated_at DESC LIMIT 5').bind(userId).all();
    
    // 2. Map claims
    const activeClaims = claims.map((c: any) => ({
      claimId: c.id,
      title: c.title,
      claimant: userName,
      amount: c.claim_amount ? 'R' + c.claim_amount : 'TBD',
      currentStage: c.stage,
      lastUpdated: c.updated_at,
      sideState: c.stage === 'INFO_NEEDED' ? 'infoNeeded' : c.stage === 'REJECTED' ? 'rejected' : c.stage === 'APPEAL' ? 'appeal' : null
    }));

    // 3. Summaries
    const summaryStages = activeClaims.map((c: any) => ({
      claimId: c.claimId,
      policyName: c.title,
      currentStage: c.currentStage,
      sideState: c.sideState,
      stageDescription: 'Standard review in progress.',
      stageEnteredAt: c.lastUpdated,
      milestones: [
        { title: 'Submitted', isCompleted: true },
        { title: 'Verified', isCompleted: c.currentStage !== 'SUBMITTED' },
        { title: 'Screening', isCompleted: !['SUBMITTED', 'VERIFIED'].includes(c.currentStage) },
        { title: 'Review', isCompleted: ['DECISION', 'PAID'].includes(c.currentStage) },
        { title: 'Decision', isCompleted: c.currentStage === 'PAID' },
        { title: 'Paid', isCompleted: c.currentStage === 'PAID' }
      ]
    }));

    // 4. Return combined
    return {
      userId,
      userName: userName,
      welcomeMessage: 'Your cover is active.',
      activeClaims,
      summaryStages,
      mostlyVisited: [
        { id: '1', title: 'Submit Claim', icon: '📝', visitCount: 15, route: '/claims' }
      ],
      recentActivities: [],
      notifications: []
    };
  }
}
