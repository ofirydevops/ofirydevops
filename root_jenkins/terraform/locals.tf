locals {
    global_conf    = jsondecode(file("${path.module}/../../global_conf.json"))
    region         = local.global_conf["region"]
    ecr_endpoint   = data.aws_ecr_authorization_token.ecr_token.proxy_endpoint
    default_vpc_id = data.aws_vpc.default.id
    domain         = local.global_conf["domain"]
    profile        = local.global_conf["profile"]
}

data "aws_ecr_authorization_token" "ecr_token" {}
data "aws_vpc" "default" {
  default = true
}
