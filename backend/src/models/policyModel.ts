export class PolicyModel {
  static async getMyCovers(db: D1Database, userId: string) {
    const { results } = await db.prepare('SELECT * FROM policies WHERE user_id = ?').bind(userId).all()
    return results
  }
}
