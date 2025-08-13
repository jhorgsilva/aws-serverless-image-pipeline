# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
  
  tags = {
    Environment = var.environment
    Project     = "image-processor"
  }
}

resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/${var.eks_cluster_name}/cluster"
  retention_in_days = 14
  
  tags = {
    Environment = var.environment
    Project     = "image-processor"
  }
}

# CloudWatch Alarms for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Environment = var.environment
    Project     = "image-processor"
  }
}

# CloudWatch Alarm for Lambda duration
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.environment}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Average"
  threshold           = "30000"  # 30 seconds
  alarm_description   = "This metric monitors lambda duration"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Environment = var.environment
    Project     = "image-processor"
  }
}

# CloudWatch Alarm for SQS queue depth
resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  alarm_name          = "${var.environment}-sqs-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"  # 5 minutes
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "This metric monitors SQS queue depth"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }

  tags = {
    Environment = var.environment
    Project     = "image-processor"
  }
}

# CloudWatch Alarm for EKS pod restarts
resource "aws_cloudwatch_metric_alarm" "eks_pod_restarts" {
  count               = var.enable_eks_monitoring ? 1 : 0
  alarm_name          = "${var.environment}-eks-pod-restarts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "pod_restart_total"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "This metric monitors EKS pod restarts"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ClusterName = var.eks_cluster_name
  }

  tags = {
    Environment = var.environment
    Project     = "image-processor"
  }
}
