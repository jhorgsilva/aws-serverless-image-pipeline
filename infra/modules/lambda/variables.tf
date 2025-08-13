variable "lambda_role_name" {
  description = "Name of the Lambda execution role"
  type        = string
}

variable "lambda_policy_name" {
  description = "Name of the Lambda IAM policy"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for publishing messages"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs18.x"
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket that will trigger the Lambda"
  type        = string
}
