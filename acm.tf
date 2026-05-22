resource "aws_acm_certificate" "alb" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn = aws_acm_certificate.alb.arn
  timeouts {
    create = "45m"
  }
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.cloudfront.arn
  timeouts {
    create = "45m"
  }
}

output "acm_validation_cname_name" {
  value = tolist(aws_acm_certificate.alb.domain_validation_options)[0].resource_record_name
}

output "acm_validation_cname_value" {
  value = tolist(aws_acm_certificate.alb.domain_validation_options)[0].resource_record_value
}
