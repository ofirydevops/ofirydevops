locals {
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))
    secrets = yamldecode(file("${path.module}/../../secrets.yaml"))
    region = local.global_conf["region"]
    ecr_endpoint = data.aws_ecr_authorization_token.ecr_token.proxy_endpoint
    default_vpc_id = data.aws_vpc.default.id
    domain = local.global_conf["domain"]
}

data "aws_ecr_authorization_token" "ecr_token" {}
data "aws_vpc" "default" {
  default = true
}