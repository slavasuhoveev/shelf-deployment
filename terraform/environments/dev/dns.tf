data "aws_lb" "shelful_dev" {
  tags = {
    "elbv2.k8s.aws/cluster" = "shelful-dev"
  }
}

resource "aws_route53_record" "dev" {
  zone_id = data.aws_route53_zone.shelful.zone_id
  name    = "dev.shelful.club"
  type    = "A"

  alias {
    name                   = "dualstack.${data.aws_lb.shelful_dev.dns_name}"
    zone_id                = data.aws_lb.shelful_dev.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_dev" {
  zone_id = data.aws_route53_zone.shelful.zone_id
  name    = "api.dev.shelful.club"
  type    = "A"

  alias {
    name                   = "dualstack.${data.aws_lb.shelful_dev.dns_name}"
    zone_id                = data.aws_lb.shelful_dev.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "auth_dev" {
  zone_id = data.aws_route53_zone.shelful.zone_id
  name    = "auth.dev.shelful.club"
  type    = "A"

  alias {
    name                   = "dualstack.${data.aws_lb.shelful_dev.dns_name}"
    zone_id                = data.aws_lb.shelful_dev.zone_id
    evaluate_target_health = false
  }
}
