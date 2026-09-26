export class IdentityService {
  static async getProfile(db: D1Database, userId: string) {
    const { results } = await db.prepare('SELECT * FROM users WHERE id = ?').bind(userId).all();
    return results.length > 0 ? results[0] : null;
  }

  static async updateProfile(db: D1Database, userId: string, data: any) {
    const updates: string[] = [];
    const values: any[] = [];
    if (data.first_name) { updates.push('first_name = ?'); values.push(data.first_name); }
    if (data.last_name) { updates.push('last_name = ?'); values.push(data.last_name); }
    if (data.phone) { updates.push('phone = ?'); values.push(data.phone); }
    if (data.address) { updates.push('address = ?'); values.push(data.address); }
    
    if (updates.length > 0) {
      updates.push('updated_at = CURRENT_TIMESTAMP');
      values.push(userId);
      await db.prepare(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`).bind(...values).run();
    }
    return this.getProfile(db, userId);
  }

  static async getConsents(db: D1Database, userId: string) {
    const { results } = await db.prepare('SELECT * FROM consents WHERE user_id = ?').bind(userId).all();
    return results;
  }

  static async checkMandate(db: D1Database, tenantId: string, userId: string) {
    const { results } = await db.prepare('SELECT * FROM mandates WHERE user_id = ? AND provider_name = ? AND status = ?').bind(userId, tenantId, 'Active').all();
    return results.length > 0 ? results[0] : null;
  }
  
  static async cancelMandate(db: D1Database, mandateId: string) {
    await db.prepare('UPDATE mandates SET status = ? WHERE id = ?').bind('Cancelled', mandateId).run();
    return { 
      status: 'success',
      message: 'Debit order mandate successfully cancelled.',
      cancellationDate: new Date().toISOString()
    };
  }

  static async login(db: D1Database, idNumber: string) {
    const { results } = await db.prepare('SELECT * FROM users WHERE id_number = ?').bind(idNumber).all();
    if (results.length > 0) {
      const user = results[0];
      return {
        status: 'success',
        message: 'Login successful',
        token: `mock-jwt-token-${user.id}`,
        profile: user
      };
    }
    return null;
  }
}
