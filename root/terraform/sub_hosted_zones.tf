locals {

    enable_sub_hosted_zones = false
    sub_hosted_zones = local.enable_sub_hosted_zones ? ["dev", "stg", "sbx"] : []
}

resource "aws_route53_zone" "sub_hosted_zones" {
    for_each = toset(local.sub_hosted_zones)
    name = "${each.key}.${local.domain}"
}

resource "aws_route53_record" "sub_hosted_zones_nameservers" {
    for_each = toset(local.sub_hosted_zones)
    zone_id  = aws_route53_zone.main.zone_id
    name     = each.key
    type     = "NS"
    ttl      = 3600
    records  = aws_route53_zone.sub_hosted_zones[each.key].name_servers
}
