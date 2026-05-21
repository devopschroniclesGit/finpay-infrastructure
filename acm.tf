# ─────────────────────────────────────────────────────────────────────────────
# ACM — TLS Certificates
#
# We need TWO certificates:
#   1. Regional cert (var.aws_region) — attached to the ALB
#   2. us-east-1 cert — attached to CloudFront (AWS requirement, Commit 4)
#
# Both validate via DNS automatically using Route 53.
# Certificate provisioning takes 2-5 minutes on first apply.
# ─────────────────────────────────────────────────────────────────────────────

# Certificate in the app's deployment region — used by the ALB
resource "aws_acm_certificate" "alb" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  # Required for zero-downtime cert rotation:
  # Terraform creates the new cert before destroying the old one
  lifecycle {
    create_before_destroy = true
  }
}

# Certificate in us-east-1 — CloudFront only accepts certs from this region
# Uses the aliased provider defined in main.tf
resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Look up the hosted zone for your domain
data "aws_route53_zone" "finpay" {
  name         = var.route53_zone_name  # e.g. "devopschronicles.com"
  private_zone = false
}

# Create DNS validation records for the ALB cert
# These prove to AWS that you own the domain
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.finpay.zone_id
}

# Wait for AWS to validate the ALB cert before attaching it to the ALB
resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# Validation for the CloudFront cert (same DNS records, different cert ARN)
resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
