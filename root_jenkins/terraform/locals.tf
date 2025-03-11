locals {
    secrets = yamldecode(file("${path.module}/../../secrets.yaml"))
    region = local.global_conf["region"]
    ecr_endpoint = data.aws_ecr_authorization_token.ecr_token.proxy_endpoint
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))

    default_vpc_id = local.global_conf["default_vpc_id"]
    default_public_subnets = local.global_conf["default_public_subnets"]
}

data "aws_ecr_authorization_token" "ecr_token" {}
