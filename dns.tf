resource "aws_route53_zone" "production" {
  name = "hashikite.com"
}

resource "aws_acm_certificate" "production" {
	domain_name               = aws_route53_zone.production.name
	subject_alternative_names = ["*.${aws_route53_zone.production.name}"]
	validation_method         = "DNS"
}

resource "aws_route53_record" "production-cert-validation" {
	zone_id  = aws_route53_zone.production.id
	name     = aws_acm_certificate.production.domain_validation_options[0].resource_record_name
	type     = aws_acm_certificate.production.domain_validation_options[0].resource_record_type
	records  = [aws_acm_certificate.production.domain_validation_options[0].resource_record_value]
	ttl      = 60
}

resource "aws_acm_certificate_validation" "production" {
  certificate_arn         = aws_acm_certificate.production.arn
  validation_record_fqdns = [aws_route53_record.production-cert-validation.fqdn]
}
