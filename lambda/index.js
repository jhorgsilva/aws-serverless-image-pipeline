// lambda/index.js - Simple S3 to SNS publisher
const { SNS } = require('@aws-sdk/client-sns');
const sns = new SNS();

exports.handler = async (event) => {
  console.log("Received S3 Event:", JSON.stringify(event, null, 2));

  try {
    // Get bucket name & object key from S3 event
    const record = event.Records[0];
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

    console.log(`New file uploaded: ${bucket}/${key}`);

    // Skip processing if the file is already a thumbnail or in thumbnails folder
    if (key.startsWith('thumbnails/') || key.includes('_thumb')) {
      console.log(`Skipping thumbnail file: ${key}`);
      return { statusCode: 200, body: "Thumbnail file skipped" };
    }

    // Only process original images (common image extensions)
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    const hasImageExtension = imageExtensions.some(ext => 
      key.toLowerCase().endsWith(ext)
    );

    if (!hasImageExtension) {
      console.log(`Skipping non-image file: ${key}`);
      return { statusCode: 200, body: "Non-image file skipped" };
    }

    // Publish message to SNS topic
    const params = {
      TopicArn: process.env.SNS_TOPIC_ARN, // We'll set this as an environment variable
      Message: JSON.stringify({ bucket, key }),
      Subject: "New S3 Upload"
    };

    await sns.publish(params);
    console.log("Image processing notification sent to SNS successfully.");

    return { statusCode: 200, body: "SNS Publish Success" };
  } catch (error) {
    console.error("Error publishing to SNS:", error);
    throw error;
  }
};