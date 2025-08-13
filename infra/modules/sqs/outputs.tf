output "queue_id" {
  description = "The URL for the created Amazon SQS queue"
  value       = aws_sqs_queue.this.id
}

output "queue_arn" {
  description = "The ARN of the SQS queue"
  value       = aws_sqs_queue.this.arn
}

output "queue_name" {
  description = "The name of the SQS queue"
  value       = aws_sqs_queue.this.name
}

output "queue_url" {
  description = "Same as queue_id - The URL for the created Amazon SQS queue"
  value       = aws_sqs_queue.this.url
}

output "dlq_id" {
  description = "The URL for the created Amazon SQS dead letter queue"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].id : null
}

output "dlq_arn" {
  description = "The ARN of the SQS dead letter queue"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].arn : null
}
