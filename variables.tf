variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "notification_email" {
  description = "Email address to receive daily cost notifications"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule expression (default: 9 AM JST daily)"
  type        = string
  default     = "cron(0 0 * * ? *)" # UTC 00:00 = JST 09:00
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "daily-cost-monitor"
}

variable "days_to_check" {
  description = "Number of days to retrieve cost data"
  type        = number
  default     = 7
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "system_name" {
  description = "System name for tagging"
  type        = string
  default     = "dailycost"
}

# Common tags for all resources
locals {
  common_tags = {
    env    = var.environment
    system = var.system_name
  }
}

