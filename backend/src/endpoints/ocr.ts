import { Hono } from 'hono'
import { z } from 'zod'
import type { AppEnv, Bindings } from '../types'
import { requireRole } from '../security/rbac'

const router = new Hono<AppEnv>()

// Stub: no OCR engine exists yet. Restricted to insurer roles; customers use
// POST /claims/:claimId/evidence-ocr instead.
router.post('/process', requireRole('ASSESSOR', 'MANAGER'), (c) => c.json({ extracted: true }))

// Queue messages are untrusted input: validate shape before acting on them.
const claimEventSchema = z.object({
  event: z.enum(['ClaimSubmitted', 'ClaimEvidenceUploaded']),
  data: z.object({ claimId: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/), timestamp: z.string() }),
})

// Function to process messages from the queue
export async function processQueueBatch(batch: MessageBatch<unknown>, envUncast: unknown) {
  const env = envUncast as Bindings;
  for (const message of batch.messages) {
    try {
      const parsed = claimEventSchema.safeParse(message.body)
      if (!parsed.success) {
        console.warn(`Discarding malformed queue message: ${message.id}`)
        message.ack()
        continue
      }

      const { event, data } = parsed.data
      if (event === 'ClaimSubmitted') {
        console.log(`OCR Service processing claim: ${data.claimId}`)
        console.log(`Successfully completed OCR for ${data.claimId}`)
      } else if (event === 'ClaimEvidenceUploaded') {
        console.log(`OCR Service processing evidence for claim: ${data.claimId}`)
        
        // 1. Fetch latest evidence for this claim
        const latestEvidence = await env.DB.prepare(
          `SELECT id, storage_key, mime_type FROM evidence WHERE claim_id = ? ORDER BY created_at DESC LIMIT 1`
        ).bind(data.claimId).first<{id: string, storage_key: string, mime_type: string}>()
        
        if (!latestEvidence) {
           console.log(`No evidence found for claim ${data.claimId}.`)
           message.ack()
           continue
        }
        
        // 2. Fetch the file from R2
        if (!env.EVIDENCE_BUCKET) {
           console.warn('EVIDENCE_BUCKET not bound, skipping OCR.')
           message.ack()
           continue
        }
        const fileObj = await env.EVIDENCE_BUCKET.get(latestEvidence.storage_key)
        if (!fileObj) {
           console.warn(`File ${latestEvidence.storage_key} not found in R2.`)
           message.ack()
           continue
        }
        
        const bytes = new Uint8Array(await fileObj.arrayBuffer())
        
        // 3. Call Cloudflare Workers AI for image-to-text (OCR)
        if (!env.AI) {
           console.warn('Workers AI not bound, skipping OCR extraction.')
           message.ack()
           continue
        }
        
        console.log(`Running OCR model on evidence ${latestEvidence.id}...`)
        // Using Cloudflare Workers AI Llama 3 Vision (or similar)
        let extractedText = ""
        try {
            const aiResponse = await env.AI.run('@cf/meta/llama-3-vision-instruct', {
                image: [...bytes],
                prompt: "Extract all text from this receipt or document and output only the text."
            })
            extractedText = aiResponse?.response || aiResponse?.text || "Extracted text via AI."
        } catch (err) {
            console.error("AI execution failed:", err)
            extractedText = "AI OCR Failed."
        }
        
        // 4. Update evidence record
        try {
           await env.DB.prepare(`UPDATE evidence SET extracted_text = ? WHERE id = ?`)
             .bind(extractedText, latestEvidence.id)
             .run()
           console.log(`Successfully extracted text for evidence ${latestEvidence.id}`)
        } catch (dbErr) {
           console.error("Database update failed (schema might be missing extracted_text column):", dbErr)
        }
      }

      // Acknowledge the message so it's removed from the queue
      message.ack()
    } catch (error) {
      console.error(`Failed to process message: ${message.id}`, error)
      // Let it retry
      message.retry()
    }
  }
}

export default router
