variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email address for error alerts"
  type        = string
  default     = "karimzakzouk@outlook.com"
}
