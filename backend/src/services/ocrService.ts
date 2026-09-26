export class OcrService {
  static async processDocument(db: D1Database, body: any) {
    const id = crypto.randomUUID();
    const userId = body.userId || 'user123';
    const claimId = body.claimId || null;
    const documentType = body.documentType || 'General';
    const fileUrl = body.fileUrl || 'http://example.com/file.png';
    const extractedData = { extracted: true, text: "Mock extracted text for " + documentType };

    await db.prepare(
      'INSERT INTO documents (id, user_id, claim_id, document_type, file_url, ocr_status, ocr_extracted_data) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(id, userId, claimId, documentType, fileUrl, 'Completed', JSON.stringify(extractedData)).run();

    return { id, extracted: true, data: extractedData };
  }
}
