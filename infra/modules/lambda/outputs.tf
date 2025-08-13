output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "lambda_permission" {
  description = "The Lambda permission resource for dependency management"
  value       = aws_lambda_permission.allow_s3
}
