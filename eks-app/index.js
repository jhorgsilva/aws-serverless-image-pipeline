// eks-app/index.js - Simple image processor
const { S3 } = require('@aws-sdk/client-s3');
const { SQS } = require('@aws-sdk/client-sqs');
const sharp = require('sharp');

const s3 = new S3();
const sqs = new SQS();

const QUEUE_URL = process.env.SQS_QUEUE_URL;

async function processMessages() {
    while (true) {
        try {
            // Poll SQS
            const result = await sqs.receiveMessage({
                QueueUrl: QUEUE_URL,
                WaitTimeSeconds: 20,
                MaxNumberOfMessages: 1
            });
            
            if (!result.Messages) {
                console.log('No messages');
                continue;
            }
            
            for (const msg of result.Messages) {
                await processImage(msg);
                
                // Delete message
                await sqs.deleteMessage({
                    QueueUrl: QUEUE_URL,
                    ReceiptHandle: msg.ReceiptHandle
                });
            }
        } catch (error) {
            console.error('Processing error:', error);
            // Make it fail hard to trigger alarms
            await new Promise(r => setTimeout(r, 5000));
        }
    }
}

async function processImage(message) {
    try {
        // Parse SNS message
        const snsBody = JSON.parse(message.Body);
        const { bucket, key } = JSON.parse(snsBody.Message);
        
        console.log(`Processing ${bucket}/${key}`);
        
        // Download image
        const obj = await s3.getObject({ Bucket: bucket, Key: key });
        const buffer = Buffer.from(await obj.Body.transformToByteArray());
        
        // Resize with Sharp
        const thumbnail = await sharp(buffer)
            .resize(300, 300, { fit: 'inside' })
            .jpeg({ quality: 80 })
            .toBuffer();
        
        // Upload thumbnail
        const thumbKey = `thumbnails/${key.replace(/\.[^.]+$/, '_thumb.jpg')}`;
        await s3.putObject({
            Bucket: bucket,
            Key: thumbKey,
            Body: thumbnail,
            ContentType: 'image/jpeg'
        });
        
        console.log(`Created thumbnail: ${thumbKey}`);
        
    } catch (error) {
        console.error('Image processing failed:', error);
        // Make it fail hard instead of just throwing
        process.exit(1);
    }
}

console.log('Starting image processor...');
processMessages();