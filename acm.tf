# ─────────────────────────────────────────────────────────────────────────────
# ACM — TLS Certificates
#
# Two certs needed:
#   1. var.aws_region  → attached to the ALB
#   2. us-east-1       → attached to CloudFront (AWS hard requirement)
#
# DNS validation requires you to add a CNAME record at Afrihost.
# Terraform will output exactly what to add.
#
# IMPORTANT APPLY SEQUENCE (see bottom of this file for instructions):
#   Step 1: terraform apply -target=aws_acm_certificate.alb \
#                           -target=aws_acm_certificate.cloudfront
#   Step 2: Add the CNAME records at Afrihost (takes 2 min)
#   Step 3: terraform apply  ← completes everything else
# ─────────────────────────────────────────────────────────────────────────────

# Regional cert — used by the ALB in whatever region you deploy to
resource "aws_acm_certificate" "alb" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# us-east-1 cert — CloudFront will not accept a cert from any other region
resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ── Validation ────────────────────────────────────────────────────────────────
# These resources tell Terraform to WAIT until AWS confirms the certs are valid.
# They will hang here until you add the CNAME at Afrihost.
# Timeout is 75 minutes — you have plenty of time.

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn = aws_acm_certificate.alb.arn

  # No validation_record_fqdns here because we can't auto-create
  # the DNS record at Afrihost — we add it manually instead.
  # Terraform will poll ACM until AWS sees the record and issues the cert.
  timeouts {
    create = "30m"
  }
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.cloudfront.arn

  timeouts {
    create = "30m"
  }
}

# ── Outputs — what to add at Afrihost ────────────────────────────────────────
# After running: terraform apply -target=aws_acm_certificate.alb
# These outputs tell you the exact CNAME to add.
# Both certs use the same domain so one CNAME validates both.

output "acm_validation_cname_name" {
  description = "Add this as a CNAME record NAME at Afrihost"
  value       = tolist(aws_acm_certificate.alb.domain_validation_options)[0].resource_record_name
}

output "acm_validation_cname_value" {
  description = "Add this as the CNAME record VALUE at Afrihost"
  value       = tolist(aws_acm_certificate.alb.domain_validation_options)[0].resource_record_value
}
