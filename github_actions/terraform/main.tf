

data "aws_ssm_parameter" "params" {
  for_each = toset(local.ssm_params_to_read)
  name     = each.value
}

locals {
  global_conf = yamldecode(file("${path.module}/../../pylib/ofirydevops/global_conf.yaml"))

  namespace = local.global_conf["namespace"]
  profile   = local.global_conf["profile"]
  region    = local.global_conf["region"]
  ssm       = { for name in local.ssm_params_to_read : name => data.aws_ssm_parameter.params[name].value }

  ssm_params_to_read = [
    "/${local.namespace}/main_keypair_name",
    "/${local.namespace}/local_workstation_pub_ip",
    "/${local.namespace}/github_repos",
    "/${local.namespace}/secrets/aws_github_runner_app_private_key",
    "/${local.namespace}/secrets/aws_github_runner_app_id",
    "/${local.namespace}/secrets/github_token"
  ]
}

module "github_actions" {
  source                            = "../../tf_modules/github_actions"
  profile                           = local.profile
  region                            = local.region
  namespace                         = local.namespace
  vpc_id                            = local.vpc_id
  subnet_ids                        = local.public_subnet_ids
  keypair_name                      = local.ssm["/${local.namespace}/main_keypair_name"]
  local_workstation_pub_ip          = local.ssm["/${local.namespace}/local_workstation_pub_ip"]
  aws_github_runner_app_private_key = local.ssm["/${local.namespace}/secrets/aws_github_runner_app_private_key"]
  aws_github_runner_app_id          = local.ssm["/${local.namespace}/secrets/aws_github_runner_app_id"]
  github_repos                      = jsondecode(local.ssm["/${local.namespace}/github_repos"])
  github_token                      = local.ssm["/${local.namespace}/secrets/github_token"]
  runner_configs_dir_abs_path       = abspath("${path.module}/runner_configs")
}
