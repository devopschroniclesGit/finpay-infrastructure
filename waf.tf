# ─────────────────────────────────────────────────────────────────────────────
# WAF v2 — Web Application Firewall
#
# Attached to the ALB. Every inbound request is evaluated against these rules
# in priority order. First matching rule wins.
#
# Rule priority order:
#   1 → Common attack patterns  (AWS managed)
#   2 → SQL injection            (AWS managed)
#   3 → Known bad inputs         (AWS managed, includes Log4Shell etc.)
#   4 → Rate limiting            (custom — blocks IPs above threshold)
#
# If a managed rule causes false positives on your API:
#   Change override_action from: none {}
#                            to: count {}
# This logs the match without blocking, so you can investigate safely.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_wafv2_web_acl" "finpay" {
  name  = "${var.app_name}-waf"
  scope = "REGIONAL"  # REGIONAL attaches to ALB; CLOUDFRONT would attach to CloudFront

  # Default: allow everything not explicitly blocked
  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}  # enforce — change to count{} if you see false positives
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-bad-inputs-rules"
      sampled_requests_enabled   = true
    }
  }

  # Custom rate limit — blocks IPs exceeding 2000 req/5min
  # Adjust waf_rate_limit in tfvars based on your expected traffic
  rule {
    name     = "RateLimitPerIP"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.app_name}-waf-acl"
    sampled_requests_enabled   = true
  }
}

# Attach the WebACL to the ALB created in Commit 2
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.finpay.arn
  web_acl_arn  = aws_wafv2_web_acl.finpay.arn
}

# WAF logs every blocked request to CloudWatch
# Useful for: seeing what's being blocked, tuning rate limits, incident investigation
resource "aws_cloudwatch_log_group" "waf" {
  # AWS requires WAF log group names to start with aws-waf-logs-
  name              = "aws-waf-logs-${var.app_name}"
  retention_in_days = 30
}

resource "aws_wafv2_web_acl_logging_configuration" "finpay" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.finpay.arn
}
