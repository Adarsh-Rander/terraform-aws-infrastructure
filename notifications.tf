variable "notification_email" {
  description = "Email address for Terraform state updates"
  type        = string
}

resource "aws_sns_topic" "terraform_alerts" {
  name = "terraform-state-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.terraform_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_policy" "allow_s3" {
  arn = aws_sns_topic.terraform_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3Publish"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.terraform_alerts.arn
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:s3:::adarsh-tfstate-dynamobucket-20261029"
        }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "terraform_state_updates" {
  bucket = "adarsh-tfstate-dynamobucket-20261029"


  topic {
    topic_arn     = aws_sns_topic.terraform_alerts.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "terraform-project/"
    filter_suffix = ".tfstate"
  }

  depends_on = [aws_sns_topic_policy.allow_s3]
}
