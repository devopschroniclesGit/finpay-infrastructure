# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch Alarms + SNS
#
# Each alarm:
#   ALARM state → sends email via SNS
#   OK state    → sends recovery email (so you know it resolved)
#
# After applying, check your inbox for an SNS subscription confirmation email.
# You must click the link or alarms will not send notifications.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── EB / ALB Alarms ───────────────────────────────────────────────────────────

# Triggers if EB instances are using >80% CPU for 10 minutes
# Common cause: memory leak, runaway query, or traffic spike
resource "aws_cloudwatch_metric_alarm" "eb_cpu_high" {
  alarm_name          = "${var.app_name}-eb-cpu-high"
  alarm_description   = "EB CPU above 80% for 10 minutes — check for runaway processes or scale up"
  namespace           = "AWS/ElasticBeanstalk"
  metric_name         = "EnvironmentHealth"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    EnvironmentName = "${var.app_name}-production"
  }
}

# Triggers if any instance fails the ALB health check
# Common cause: app crash, deployment failure, OOM kill
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.app_name}-unhealthy-hosts"
  alarm_description   = "One or more instances failing health checks — app may be down"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.finpay.arn_suffix
    TargetGroup  = aws_lb_target_group.finpay.arn_suffix
  }
}

# Triggers if 5xx errors spike (>10 in 5 minutes)
# Common cause: unhandled exceptions, DB connection failures
resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "${var.app_name}-http-5xx-spike"
  alarm_description   = "More than 10 HTTP 5xx errors in 5 minutes — check app logs"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.finpay.arn_suffix
    TargetGroup  = aws_lb_target_group.finpay.arn_suffix
  }
}

# ── RDS Alarms ────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.app_name}-rds-cpu-high"
  alarm_description   = "RDS CPU above 80% for 10 minutes — check for slow queries or missing indexes"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.finpay.id
  }
}

# db.t3.micro has 20GB — alert at 2GB remaining
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.app_name}-rds-storage-low"
  alarm_description   = "RDS has less than 2GB free — increase allocated storage soon"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  comparison_operator = "LessThanThreshold"
  threshold           = 2000000000  # 2GB in bytes
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.finpay.id
  }
}

# db.t3.micro max connections ≈ 85 — alert at 70
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.app_name}-rds-connections-high"
  alarm_description   = "RDS connections above 70 — connection pool may be exhausted"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 70
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.finpay.id
  }
}

output "sns_topic_arn" {
  description = "SNS topic ARN — check email and confirm subscription after apply"
  value       = aws_sns_topic.alerts.arn
}
