variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to monitor"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster to monitor"
  type        = string
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue to monitor"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  type        = string
}

variable "enable_eks_monitoring" {
  description = "Enable EKS monitoring alarms"
  type        = bool
  default     = false
}
