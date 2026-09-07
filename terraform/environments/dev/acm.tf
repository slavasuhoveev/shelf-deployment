resource "aws_acm_certificate" "shelful_dev" {
  domain_name       = "dev.shelful.club"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.dev.shelful.club",
  ]
}

data "aws_route53_zone" "shelful" {
  name         = "shelful.club"
  private_zone = false
}

resource "aws_route53_record" "shelful_dev_acm_validation" {
  zone_id = data.aws_route53_zone.shelful.zone_id

  name = "_1885b637ba8affd7b46b92c16acb55f8.dev.shelful.club"
  type = "CNAME"
  ttl  = 300

  records = [
    "_90c22e7aad40824e72bb5497d6a2ba28.jkddzztszm.acm-validations.aws.",
  ]
}
