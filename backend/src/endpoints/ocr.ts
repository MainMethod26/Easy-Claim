import { Hono } from 'hono'

const router = new Hono()

router.post('/process', (c) => c.json({ extracted: true }))

// Function to process messages from the queue
export async function processQueueBatch(batch: MessageBatch<any>, env: any) {
  for (const message of batch.messages) {
    try {
      console.log(`Processing message: ${message.id}`);
      const payload = message.body;
      
      if (payload.event === 'ClaimSubmitted') {
        console.log(`OCR Service processing claim: ${payload.data.claimId}`);
        // Simulate OCR document processing
        // update claim status in DB, etc.
        const claimId = payload.data.claimId;
        console.log(`Successfully completed OCR for ${claimId}`);
      }
      
      // Acknowledge the message so it's removed from the queue
      message.ack();
    } catch (error) {
      console.error(`Failed to process message: ${message.id}`, error);
      // Let it retry
      message.retry();
    }
  }
}

export default router
