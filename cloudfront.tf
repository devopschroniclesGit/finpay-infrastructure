# ─────────────────────────────────────────────────────────────────────────────
# CloudFront — CDN + Edge Layer
#
# Two cache behaviours:
#   /api/*  → NO cache, forward all headers → ALB → EB → app
#   /*      → Cache static assets (React build: JS, CSS, images, fonts)
#
# The React frontend is served from EB (since client/dist is in your Docker image).
# CloudFront caches those files globally so users don't re-download them from
# Stockholm on every page load.
#
# Note: CloudFront cert MUST be in us-east-1 — handled by aws.us_east_1 provider alias
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "finpay" {
  comment             = "FinPay API + React frontend CDN"
  enabled             = true
  is_ipv6_enabled     = true
  aliases             = [var.domain_name]
  price_class         = "PriceClass_100"  # US, Canada, Europe only — cheapest tier
                                          # Change to PriceClass_All for global coverage

  # Origin = your ALB. CloudFront forwards requests here when not in cache.
  origin {
    domain_name = aws_lb.finpay.dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"   # CloudFront → ALB uses HTTPS
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # API routes — NEVER cache, pass everything through to the app
  # This must be listed before the default cache behaviour
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"

    forwarded_values {
      query_string = true   # API needs query params
      headers      = ["Authorization", "Content-Type", "Accept", "Origin",
                      "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0     # never cache API responses
    max_ttl                = 0
    compress               = true
  }

  # Default behaviour — React static assets (JS/CSS/images)
  # Long cache + compression = fast repeat visits
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"

    forwarded_values {
      query_string = false  # static assets don't need query strings
      cookies {
        forward = "none"    # no cookies needed for static files
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400     # cache for 1 day
    max_ttl                = 31536000  # browsers can cache up to 1 year
    compress               = true      # gzip/brotli compression at the edge
  }

  # Use the us-east-1 cert created in acm.tf
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"  # no geographic blocking
    }
  }
}
