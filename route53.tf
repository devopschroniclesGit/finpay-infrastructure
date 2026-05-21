# ─────────────────────────────────────────────────────────────────────────────
# Route 53 — DNS
#
# Creates an A record alias: finpay.devopschronicles.com → CloudFront
#
# Alias records are preferred over CNAMEs for AWS resources:
#   - No extra DNS lookup
#   - Free (CNAMEs on apex domains cost per query)
#   - Automatically follows CloudFront IP changes
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_route53_record" "finpay" {
  zone_id = data.aws_route53_zone.finpay.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.finpay.domain_name
    zone_id                = aws_cloudfront_distribution.finpay.hosted_zone_id
    evaluate_target_health = false  # CloudFront doesn't support target health evaluation
  }
}

output "live_url" {
  description = "Your live application URL"
  value       = "https://${var.domain_name}"
}

output "cloudfront_domain" {
  description = "CloudFront domain — use this to verify before DNS cutover"
  value       = aws_cloudfront_distribution.finpay.domain_name
}
