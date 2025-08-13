variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "force_destroy" {
  description = "Whether to force destroy the bucket"
  type        = bool
  default     = true
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to trigger"
  type        = string
}

variable "notification_events" {
  description = "S3 events that trigger the Lambda function"
  type        = list(string)
  default     = ["s3:ObjectCreated:*"]
}

variable "lambda_permission_dependency" {
  description = "Dependency on Lambda permission resource"
  type        = any
  default     = null
}
