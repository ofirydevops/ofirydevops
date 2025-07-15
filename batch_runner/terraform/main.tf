data "aws_availability_zones" "azs" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "subnet" {
  availability_zone = data.aws_availability_zones.azs.names[0]
  vpc_id            = local.vpc_id
}

data "aws_ssm_parameter" "params" {
  for_each = toset(local.ssm_params_to_read)
  name     = each.key
}

locals {
  global_conf = yamldecode(file("${path.module}/../../pylib/ofirydevops/global_conf.yaml"))
  vpc_id      = data.aws_vpc.default.id
  subnet_id   = data.aws_subnet.subnet.id
  namespace   = local.global_conf["namespace"]


  ssm_params_to_read = [
    "/${local.namespace}/main_keypair_name",
    "/${local.namespace}/local_workstation_pub_ip",
    "/${local.namespace}/ami_id/basic_amd64_100GB",
    "/${local.namespace}/ami_id/basic_arm64_100GB",
    "/${local.namespace}/ami_id/batch_gpu_amd64_100GB"
  ]
  ssm = { for name in local.ssm_params_to_read : name => data.aws_ssm_parameter.params[name].value }

}

module "batch_runner" {
  source                   = "../../tf_modules/batch_runner"
  profile                  = local.global_conf["profile"]
  region                   = local.global_conf["region"]
  namespace                = local.global_conf["namespace"]
  vpc_id                   = local.vpc_id
  subnet_ids               = [local.subnet_id]
  keypair_name             = local.ssm["/${local.namespace}/main_keypair_name"]
  local_workstation_pub_ip = local.ssm["/${local.namespace}/local_workstation_pub_ip"]
  basic_amd64_100GB_ami_id = local.ssm["/${local.namespace}/ami_id/basic_amd64_100GB"]
  basic_arm64_100GB_ami_id = local.ssm["/${local.namespace}/ami_id/basic_arm64_100GB"]
  gpu_amd64_100GB_ami_id   = local.ssm["/${local.namespace}/ami_id/batch_gpu_amd64_100GB"]

}