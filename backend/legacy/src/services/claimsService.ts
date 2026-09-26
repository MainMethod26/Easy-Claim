export class ClaimsService {
  static async initiateClaim(
    db: D1Database, 
    userId: string, 
    policyId: string, 
    cause_of_loss?: string, 
    incident_date?: string, 
    location?: string, 
    police_case_number?: string, 
    description?: string
  ) {
    const id = crypto.randomUUID();
    await db.prepare(
      'INSERT INTO claims (id, user_id, policy_id, stage, status, cause_of_loss, incident_date, location, police_case_number, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    ).bind(id, userId, policyId, 'SUBMITTED', 'Processing', cause_of_loss || null, incident_date || null, location || null, police_case_number || null, description || null).run();
    return id;
  }

  static async getClaim(db: D1Database, claimId: string) {
    const { results } = await db.prepare('SELECT * FROM claims WHERE id = ?').bind(claimId).all();
    return results.length > 0 ? results[0] : null;
  }

  static async updateStage(db: D1Database, claimId: string, stage: string) {
    await db.prepare('UPDATE claims SET stage = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').bind(stage, claimId).run();
  }

  static async setDecision(db: D1Database, claimId: string, stage: string, reason: string) {
    const status = stage === 'REJECTED' ? 'Declined' : 'Approved';
    await db.prepare('UPDATE claims SET stage = ?, status = ?, decision_reason = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').bind(stage, status, reason, claimId).run();
  }

  static async verifyEligibility(db: D1Database) {
    return { isIdentityValid: true, isPolicyActive: true, waitingPeriodCleared: true };
  }

  static async triggerEvent(env: any, eventName: string, claimId: string) {
    if (env.CLAIM_EVENTS) {
      await env.CLAIM_EVENTS.send({ event: eventName, data: { claimId, timestamp: new Date().toISOString() } });
    }
  }

  static async getTimeline(db: D1Database, claimId: string) {
    const claim = await this.getClaim(db, claimId);
    if (!claim) return [];
    
    // Simplistic timeline based on current stage
    const stages = ['SUBMITTED', 'VERIFIED', 'SCREENING', 'REVIEW', 'DECISION', 'PAID'];
    const currentIndex = stages.indexOf(claim.stage as string);
    
    return stages.map((stage, idx) => ({
      stage,
      date: idx <= currentIndex ? claim.updated_at : null,
      completed: idx <= currentIndex
    }));
  }
}
