resource "aws_route53_zone" "g2team8" {
  name          = var.domain
  force_destroy = false
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.g2team8.zone_id
  name    = var.api_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloudfront_main.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront_main.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_replica" {
  zone_id = aws_route53_zone.g2team8.zone_id
  name    = var.aus_api_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloudfront_replica.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront_replica.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "api" {
  domain_name       = var.api_domain
  validation_method = "DNS"
  tags = {
    app = "${var.namespace}"
  }
}

resource "aws_acm_certificate" "web" {
  domain_name       = var.domain
  validation_method = "DNS"
  tags = {
    app = "${var.namespace}"
  }
}

resource "aws_acm_certificate" "auth" {
  domain_name       = var.auth_domain
  validation_method = "DNS"
  tags = {
    app = "${var.namespace}"
  }
}

resource "aws_acm_certificate_validation" "api_cert" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_route53_record.api_cert_validation : record.fqdn]
}

resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.g2team8.zone_id
}

resource "aws_acm_certificate_validation" "web_cert" {
  certificate_arn         = aws_acm_certificate.web.arn
  validation_record_fqdns = [for record in aws_route53_record.web_cert_validation : record.fqdn]
}

resource "aws_route53_record" "web_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.web.domain_validation_options : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.g2team8.zone_id
}

resource "aws_acm_certificate_validation" "auth_cert" {
  certificate_arn         = aws_acm_certificate.auth.arn
  validation_record_fqdns = [for record in aws_route53_record.auth_cert_validation : record.fqdn]
}

resource "aws_route53_record" "auth_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.auth.domain_validation_options : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.g2team8.zone_id
}
