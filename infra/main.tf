provider "aws" {
  region = var.aws_region
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# ECR repository for the image processing app
module "ecr" {
  source = "./modules/ecr"
  
  repository_name      = "${var.environment}-image-processor"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  max_image_count      = 5
  untagged_expire_days = 1
  
  tags = {
    Environment = var.environment
    Purpose     = "image-processing"
  }
}

# SNS topic for image processing notifications
module "sns" {
  source     = "./modules/sns"
  topic_name = "${var.environment}-${var.sns_topic_name}"
}

# SQS queue that subscribes to SNS topic
module "sqs" {
  source         = "./modules/sqs"
  queue_name     = "${var.environment}-${var.sqs_queue_name}"
  sns_topic_arn  = module.sns.topic_arn
  create_dlq     = true
  
  # SQS configuration for handling SNS messages
  visibility_timeout_seconds = 60
  message_retention_seconds  = 1209600  # 14 days
  
  tags = {
    Environment = var.environment
    Purpose     = "image-processing"
  }
}

# Lambda function for S3 to SNS processing
module "lambda" {
  source              = "./modules/lambda"
  lambda_role_name    = "${var.environment}-lambda-s3-sns-role"
  lambda_policy_name  = "${var.environment}-lambda-s3-sns-policy"
  sns_topic_arn       = module.sns.topic_arn
  lambda_zip_path     = "../lambda/lambda.zip"
  function_name       = "${var.environment}-${var.lambda_function_name}"
  handler             = "index.handler"
  runtime             = "nodejs18.x"
  s3_bucket_arn       = module.s3.bucket_arn
  
  environment_variables = {
    SNS_TOPIC_ARN = module.sns.topic_arn
  }
}

# S3 bucket for raw images
module "s3" {
  source                       = "./modules/s3"
  bucket_name                  = "${var.environment}-${var.bucket_name}"
  force_destroy                = true
  lambda_function_arn          = module.lambda.function_arn
  notification_events          = ["s3:ObjectCreated:*"]
  lambda_permission_dependency = module.lambda.lambda_permission
}

# EKS cluster for image processing application
module "eks" {
  source = "./modules/eks"
  
  cluster_name         = "${var.environment}-${var.eks_cluster_name}"
  kubernetes_version   = var.kubernetes_version
  
  # Networking
  vpc_cidr             = var.vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  
  # Node group configuration
  capacity_type    = var.capacity_type
  instance_types   = var.instance_types
  desired_capacity = var.desired_capacity
  max_capacity     = var.max_capacity
  min_capacity     = var.min_capacity
  
  # Permissions for S3 and SQS access
  s3_bucket_arn = module.s3.bucket_arn
  sqs_queue_arn = module.sqs.queue_arn
  
  tags = {
    Environment = var.environment
    Purpose     = "image-processing"
  }
}

# SNS topic for error alerts
module "sns_alerts" {
  source = "./modules/sns-alerts"
  
  environment = var.environment
  alert_email = var.alert_email
}

# CloudWatch monitoring and alarms
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  environment           = var.environment
  lambda_function_name  = "${var.environment}-${var.lambda_function_name}"
  eks_cluster_name      = "${var.environment}-${var.eks_cluster_name}"
  sqs_queue_name        = "${var.environment}-${var.sqs_queue_name}"
  sns_topic_arn         = module.sns_alerts.error_alerts_topic_arn
  enable_eks_monitoring = false  # Disable for now due to Container Insights requirement
}