# SNS topic for email notifications
resource "aws_sns_topic" "cost_notification" {
  name         = "${var.project_name}-topic"
  display_name = "Daily AWS Cost and Resource Notification"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-${var.system_name}-topic"
    }
  )
}

# SNS topic subscription
resource "aws_sns_topic_subscription" "cost_notification_email" {
  topic_arn = aws_sns_topic.cost_notification.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# SNS topic policy to allow Lambda to publish
resource "aws_sns_topic_policy" "cost_notification_policy" {
  arn = aws_sns_topic.cost_notification.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cost_notification.arn
      }
    ]
  })
}

