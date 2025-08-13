output "error_alerts_topic_arn" {
  description = "ARN of the error alerts SNS topic"
  value       = aws_sns_topic.error_alerts.arn
}

output "error_alerts_topic_name" {
  description = "Name of the error alerts SNS topic"
  value       = aws_sns_topic.error_alerts.name
}
