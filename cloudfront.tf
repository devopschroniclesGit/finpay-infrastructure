# ─────────────────────────────────────────────────────────────────────────────
# CloudFront — CDN + Edge
#
# After apply, Terraform outputs a domain like: d1a2b3c4d5e6f7.cloudfront.net
# Go to Afrihost and add:
#   Type:  CNAME
#   Host:  finpay        (the subdomain part only)
#   Value: d1a2b3c4d5e6f7.cloudfront.net
#   TTL:   300
#
# When you terraform destroy and re-apply, CloudFront gets a new domain.
# Update the CNAME at Afrihost to the new value. Takes 2 minutes.
#
# Free tier: 1TB data out + 10M requests/month — covers any portfolio workload.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "finpay" {
  comment         = "FinPay — ${var.environment}"
  enabled         = true
  is_ipv6_enabled = true
  aliases         = [var.domain_name]  # finpay.devopschronicles.com

  # PriceClass_100 = US, Canada, Europe edge locations only
  # Cheapest tier — still includes Cape Town since AWS added African edges
  # Change to PriceClass_All if you want Asia/South America coverage
  price_class = "PriceClass_100"

  # Origin = ALB (created in alb.tf)
  # CloudFront forwards cache misses here
  origin {
    domain_name = aws_lb.finpay.dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ── API routes — NEVER cache ──────────────────────────────────────────────
  # Auth tokens, payments, wallets — must always hit the live app
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb"

    forwarded_values {
      query_string = true
      headers = [
        "Authorization",
        "Content-Type",
        "Accept",
        "Origin",
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method"
      ]
      cookies { forward = "all" }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0    # zero cache for API
    max_ttl                = 0
    compress               = true
  }

  # ── React static assets — cache aggressively ──────────────────────────────
  # JS bundles, CSS, images — content-hashed by Vite so safe to cache long
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400      # 1 day default
    max_ttl                = 31536000   # 1 year max for hashed assets
    compress               = true
  }

  # TLS cert from us-east-1 (created in acm.tf)
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# ── Outputs — what to add at Afrihost ────────────────────────────────────────

output "cloudfront_domain" {
  description = "Add this as a CNAME value at Afrihost for finpay.devopschronicles.com"
  value       = aws_cloudfront_distribution.finpay.domain_name
}

output "live_url" {
  description = "Your live URL (works after adding CNAME at Afrihost)"
  value       = "https://${var.domain_name}"
}
