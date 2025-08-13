output "lambda_log_group_name" {
  description = "Name of the Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "eks_log_group_name" {
  description = "Name of the EKS CloudWatch log group"
  value       = aws_cloudwatch_log_group.eks_logs.name
}

output "lambda_error_alarm_arn" {
  description = "ARN of the Lambda error alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_errors.arn
}

output "sqs_queue_depth_alarm_arn" {
  description = "ARN of the SQS queue depth alarm"
  value       = aws_cloudwatch_metric_alarm.sqs_queue_depth.arn
}
