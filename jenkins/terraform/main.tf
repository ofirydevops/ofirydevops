data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "jenkins_subnet" {
  availability_zone = local.jenkins_volume_az
  vpc_id            = local.vpc_id
}


data "aws_ssm_parameters_by_path" "namespace_params" {
  path            = "/${local.namespace}"
  recursive       = true  
  with_decryption = true
}

locals {

    param_names  = data.aws_ssm_parameters_by_path.namespace_params.names
    param_values = data.aws_ssm_parameters_by_path.namespace_params.values
    ssm = zipmap(
      local.param_names,
      local.param_values
    )

    global_conf = yamldecode(file("${path.module}/../../pylib/ofirydevops/global_conf.yaml"))
    region      = local.global_conf["region"]
    profile     = local.global_conf["profile"]
    namespace   = local.global_conf["namespace"]
    vpc_id      = data.aws_vpc.default.id
    subnet_id   = data.aws_subnet.jenkins_subnet.id
    domain      = local.ssm["/${local.namespace}/secrets/domain"]
    jenkins_subnet_id = data.aws_subnet.jenkins_subnet.id
    batch_envs        = jsondecode(try(local.ssm["/${local.namespace}/batch_envs"], "[null]"))


    dsl_config = merge(
      jsondecode(local.ssm["/${local.namespace}/jenkins_dsl_config_json"]),
      { "batch_envs" = local.batch_envs }
      )
}


module "jenkins" {
    source                                   = "../../tf_modules/jenkins"
    profile                                  = local.profile
    region                                   = local.region
    namespace                                = local.namespace
    vpc_id                                   = local.vpc_id
    subnet_id                                = local.subnet_id
    ebs_volume_id                            = local.jenkins_volume_id
    domain                                   = local.domain
    subdomain                                = "jenkins"
    keypair_name                             = local.ssm["/${local.namespace}/main_keypair_name"]
    github_repos                             = jsondecode(local.ssm["/${local.namespace}/github_repos"])
    dsl_config                               = local.dsl_config
    local_workstation_pub_ip                 = local.ssm["/${local.namespace}/local_workstation_pub_ip"]
    keypair_privete_key                      = local.ssm["/${local.namespace}/secrets/main_keypair_privete_key"]
    github_jenkins_app_private_key_converted = local.ssm["/${local.namespace}/secrets/github_jenkins_app_private_key_converted"]
    github_jenkins_app_id                    = local.ssm["/${local.namespace}/secrets/github_jenkins_app_id"]
    github_token                             = local.ssm["/${local.namespace}/secrets/github_token"]
    jenkins_admin_username                   = local.ssm["/${local.namespace}/secrets/jenkins_admin_username"]
    jenkins_admin_password                   = local.ssm["/${local.namespace}/secrets/jenkins_admin_password"]
    domain_route53_hosted_zone_id            = local.ssm["/${local.namespace}/secrets/domain_route53_hosted_zone_id"]
    domain_ssl_cert                          = local.ssm["/${local.namespace}/sslcerts/ofirydevops.com/cert"]
    domain_ssl_chain                         = local.ssm["/${local.namespace}/sslcerts/ofirydevops.com/chain"]
    domain_ssl_privatekey                    = local.ssm["/${local.namespace}/sslcerts/ofirydevops.com/privateKey"]

    ami_ids = {
        basic_amd64_100GB = local.ssm["/${local.namespace}/ami_id/basic_amd64_100GB"]
        basic_arm64_100GB = local.ssm["/${local.namespace}/ami_id/basic_arm64_100GB"]
        gpu_amd64_100GB   = local.ssm["/${local.namespace}/ami_id/gpu_amd64_100GB"]
    }
}
