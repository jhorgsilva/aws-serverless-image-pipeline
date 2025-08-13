# SNS topic for error alerts
resource "aws_sns_topic" "error_alerts" {
  name = "${var.environment}-error-alerts"
  
  tags = {
    Environment = var.environment
    Project     = "image-processor"
  }
}

# SNS email subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.error_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS topic policy
resource "aws_sns_topic_policy" "error_alerts_policy" {
  arn = aws_sns_topic.error_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = "SNS:Publish"
        Resource = aws_sns_topic.error_alerts.arn
      }
    ]
  })
}
