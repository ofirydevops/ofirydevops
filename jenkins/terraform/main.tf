data "aws_ssm_parameter" "params" {
  for_each        = toset(local.ssm_params_to_read)
  name            = each.value
  with_decryption = true
}

data "aws_ssm_parameter" "ssl_cert_params" {
  for_each        = nonsensitive(toset(local.ssl_cert_params))
  name            = each.value
  with_decryption = true
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "jenkins_subnet" {
  availability_zone = local.jenkins_volume_az
  vpc_id            = local.vpc_id
}

locals {

    global_conf = yamldecode(file("${path.module}/../../pylib/ofirydevops/global_conf.yaml"))
    region      = local.global_conf["region"]
    profile     = local.global_conf["profile"]
    namespace   = local.global_conf["namespace"]
    vpc_id      = data.aws_vpc.default.id
    subnet_id   = data.aws_subnet.jenkins_subnet.id
    domain      = local.ssm["/${local.namespace}/secrets/domain"]
    ssm_params_to_read = [
      "/${local.namespace}/ami_id/basic_amd64_100GB",
      "/${local.namespace}/ami_id/basic_arm64_100GB",
      "/${local.namespace}/ami_id/gpu_amd64_100GB",
      "/${local.namespace}/main_keypair_name",
      "/${local.namespace}/example_github_repo_url",
      "/${local.namespace}/example_github_repo_name",
      "/${local.namespace}/example_github_jenkinsfile_path",
      "/${local.namespace}/github_repos",
      "/${local.namespace}/local_workstation_pub_ip",
      "/${local.namespace}/secrets/domain_route53_hosted_zone_id",
      "/${local.namespace}/secrets/domain",
      "/${local.namespace}/secrets/main_keypair_privete_key",
      "/${local.namespace}/secrets/main_keypair_pub_key",
      "/${local.namespace}/secrets/github_token",
      "/${local.namespace}/secrets/jenkins_admin_password",
      "/${local.namespace}/secrets/jenkins_admin_username",
      "/${local.namespace}/secrets/github_jenkins_app_private_key_converted",
      "/${local.namespace}/secrets/github_jenkins_app_id"
    ]

    ssl_cert_params = [
      "/${local.namespace}/sslcerts/${local.domain}/privateKey",
      "/${local.namespace}/sslcerts/${local.domain}/chain",
      "/${local.namespace}/sslcerts/${local.domain}/cert"
    ]

    ssm               = { for name in local.ssm_params_to_read : name => data.aws_ssm_parameter.params[name].value }
    ssl_cert_ssm_data = { for name in local.ssl_cert_params : name => data.aws_ssm_parameter.ssl_cert_params[name].value }
    jenkins_subnet_id = data.aws_subnet.jenkins_subnet.id
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
    example_github_repo_url                  = local.ssm["/${local.namespace}/example_github_repo_url"]
    example_github_repo_name                 = local.ssm["/${local.namespace}/example_github_repo_name"]
    example_github_jenkinsfile_path          = local.ssm["/${local.namespace}/example_github_jenkinsfile_path"]
    local_workstation_pub_ip                 = local.ssm["/${local.namespace}/local_workstation_pub_ip"]
    keypair_privete_key                      = local.ssm["/${local.namespace}/secrets/main_keypair_privete_key"]
    github_jenkins_app_private_key_converted = local.ssm["/${local.namespace}/secrets/github_jenkins_app_private_key_converted"]
    github_jenkins_app_id                    = local.ssm["/${local.namespace}/secrets/github_jenkins_app_id"]
    github_token                             = local.ssm["/${local.namespace}/secrets/github_token"]
    jenkins_admin_username                   = local.ssm["/${local.namespace}/secrets/jenkins_admin_username"]
    jenkins_admin_password                   = local.ssm["/${local.namespace}/secrets/jenkins_admin_password"]
    domain_route53_hosted_zone_id            = local.ssm["/${local.namespace}/secrets/domain_route53_hosted_zone_id"]
    domain_ssl_cert                          = local.ssl_cert_ssm_data["/${local.namespace}/sslcerts/${local.domain}/cert"]
    domain_ssl_chain                         = local.ssl_cert_ssm_data["/${local.namespace}/sslcerts/${local.domain}/chain"]
    domain_ssl_privatekey                    = local.ssl_cert_ssm_data["/${local.namespace}/sslcerts/${local.domain}/privateKey"]
    ami_ids = {
        basic_amd64_100GB = local.ssm["/${local.namespace}/ami_id/basic_amd64_100GB"]
        basic_arm64_100GB = local.ssm["/${local.namespace}/ami_id/basic_arm64_100GB"]
        gpu_amd64_100GB   = local.ssm["/${local.namespace}/ami_id/gpu_amd64_100GB"]
    }
}
