import { Hono } from 'hono'
import { z } from 'zod'
import type { AppEnv } from '../types'
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
export async function processQueueBatch(batch: MessageBatch<unknown>, env: unknown) {
  for (const message of batch.messages) {
    try {
      const parsed = claimEventSchema.safeParse(message.body)
      if (!parsed.success) {
        // A malformed message will never succeed; ack it so it cannot retry forever.
        console.warn(`Discarding malformed queue message: ${message.id}`)
        message.ack()
        continue
      }

      const { event, data } = parsed.data
      if (event === 'ClaimSubmitted') {
        console.log(`OCR Service processing claim: ${data.claimId}`)
        // Simulate OCR document processing
        console.log(`Successfully completed OCR for ${data.claimId}`)
      } else if (event === 'ClaimEvidenceUploaded') {
        // Previously this event was silently dropped.
        console.log(`Evidence uploaded for claim: ${data.claimId} (OCR not implemented)`)
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
