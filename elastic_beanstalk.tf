# ── Elastic Beanstalk ─────────────────────────────────────────────────────────

resource "aws_elastic_beanstalk_application" "finpay" {
  name        = "${var.app_name}-api"
  description = "FinPay payment API — production-style fintech platform"
}

resource "aws_elastic_beanstalk_environment" "finpay_production" {
  name                = "${var.app_name}-production"
  application         = aws_elastic_beanstalk_application.finpay.name
  solution_stack_name = var.eb_solution_stack

  # ── Environment type: single instance (no load balancer) ──────────────────
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service.arn
  }

  # ── EC2 ────────────────────────────────────────────────────────────────────
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.eb_instance_type
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance.name
  }

  # ── Health check ──────────────────────────────────────────────────────────
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/api/v1/health"
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # ── Application environment variables ─────────────────────────────────────
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = "production"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PORT"
    value     = "3000"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DATABASE_URL"
    value     = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.finpay.address}:5432/${var.db_name}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "JWT_SECRET"
    value     = var.jwt_secret
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "JWT_EXPIRES_IN"
    value     = var.jwt_expires_in
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "UPSTASH_REDIS_REST_URL"
    value     = var.upstash_redis_rest_url
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "UPSTASH_REDIS_REST_TOKEN"
    value     = var.upstash_redis_rest_token
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "RATE_LIMIT_WINDOW_MS"
    value     = var.rate_limit_window_ms
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "RATE_LIMIT_MAX_REQUESTS"
    value     = var.rate_limit_max_requests
  }

  depends_on = [aws_db_instance.finpay]
}
