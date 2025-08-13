variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for raw images"
  type        = string
  default     = "my-raw-images-bucket-1234"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = "image-uploads-topic"
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
  default     = "image-processing-queue"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "s3-to-sns"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# EKS Variables
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "image-processor"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  type        = string
  default     = "ON_DEMAND"
}

variable "instance_types" {
  description = "List of instance types associated with the EKS Node Group"
  type        = list(string)
  default     = ["t3.small"]  # Free tier friendly
}

variable "desired_capacity" {
  description = "Desired number of nodes in the EKS Node Group"
  type        = number
  default     = 1  # Single node for cost optimization
}

variable "max_capacity" {
  description = "Maximum number of nodes in the EKS Node Group"
  type        = number
  default     = 1  # Prevent scaling to avoid costs
}

variable "min_capacity" {
  description = "Minimum number of nodes in the EKS Node Group"
  type        = number
  default     = 1
}

variable "alert_email" {
  description = "Email address for error alerts"
  type        = string
  default     = "karimzakzouk@outlook.com"
}
