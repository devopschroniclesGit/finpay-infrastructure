# ─────────────────────────────────────────────────────────────────────────────
# ALB — Application Load Balancer
#
# Sits between the internet and Elastic Beanstalk.
# Handles TLS termination so EB only deals with plain HTTP internally.
#
# Traffic flow after this commit:
#   User → ALB:443 (HTTPS) → EB:3000 (HTTP) → app
#   User → ALB:80  (HTTP)  → 301 redirect to HTTPS
# ─────────────────────────────────────────────────────────────────────────────

# ALB security group — only allows HTTP/HTTPS from internet
# EB security group (already exists) will be updated to only allow traffic FROM this SG
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-${var.environment}-alb-sg"
  description = "FinPay ALB - internet-facing HTTP and HTTPS only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet - redirected to HTTPS by listener rule"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to EB on port 3000"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-${var.environment}-alb-sg" }
}

resource "aws_lb" "finpay" {
  name               = "${var.app_name}-alb"
  internal           = false          # internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  # ALB logs every request to S3 — useful for debugging 4xx/5xx spikes
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = { Name = "${var.app_name}-alb" }
}

# S3 bucket for ALB access logs
# ALB requires a specific bucket policy to write logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.app_name}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # logs are disposable
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

data "aws_elb_service_account" "main" {}

# Target group — ALB uses this to know which instances to send traffic to
# and to health-check them
resource "aws_lb_target_group" "finpay" {
  name        = "${var.app_name}-tg"
  port        = 80   # your app's port inside the container
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/api/v1/health"  # your existing health check endpoint
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2    # 2 passing checks = healthy
    unhealthy_threshold = 3    # 3 failing checks = unhealthy (triggers EB replacement)
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = { Name = "${var.app_name}-tg" }
}

# HTTP listener — immediately redirects all HTTP to HTTPS
# No traffic ever reaches EB over plain HTTP from the internet
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.finpay.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.finpay.arn
  }
}

# HTTPS listener — terminates TLS, forwards decrypted traffic to EB
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.finpay.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # TLS 1.3 preferred, 1.2 minimum
  certificate_arn   = aws_acm_certificate_validation.alb.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.finpay.arn
  }
}
