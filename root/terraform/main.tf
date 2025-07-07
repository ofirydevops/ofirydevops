data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
    global_conf               = yamldecode(file("${path.module}/../../pylib/ofirydevops/global_conf.yaml"))
    personal_info_and_secrets = yamldecode(file("${path.module}/../../personal_info_and_secrets.yaml"))
    secrets                   = local.personal_info_and_secrets["secrets"]
    github_repos              = concat([github_repository.main.name], try(local.personal_info_and_secrets["github_repos"], []))
    tf_backend_config         = local.personal_info_and_secrets["tf_backend_config"]
    region                    = local.global_conf["region"]
    profile                   = local.global_conf["profile"]
    namespace                 = local.global_conf["namespace"]
    local_workstation_pub_ip  = trimspace(data.http.my_public_ip.response_body)

    ssm_params = {

        "main_keypair_name" : {
            key = "/${local.namespace}/main_keypair_name"
            value = aws_key_pair.main.id
        }
        "github_repos" : {
            key = "/${local.namespace}/github_repos"
            value = jsonencode(local.github_repos)
        }
        "local_workstation_pub_ip" : {
            key = "/${local.namespace}/local_workstation_pub_ip"
            value = local.local_workstation_pub_ip
        }
        "tf_backend_config_json" : {
            key = "/${local.namespace}/tf_backend_config_json"
            value = jsonencode(local.tf_backend_config)
        }
        "jenkins_dsl_config_json" : {
            key = "/${local.namespace}/jenkins_dsl_config_json"
            value = local.jenkins_dsl_config_json
        }
        "all_github_repositories" : {
            key = "/${local.namespace}/all_github_repositories"
            value = jsonencode(local.all_github_repos_final)
        }

    }
}

resource "aws_key_pair" "main" {
  key_name   = "${local.namespace}_main"
  public_key = local.secrets["main_keypair_pub_key"]
}

resource "aws_ssm_parameter" "params" {
    for_each = local.ssm_params
    name     = each.value.key
    type     = try(each.value.type, "String")
    value    = each.value.value
}

resource "aws_ssm_parameter" "secrets" {
    for_each = local.secrets
    name     = "/${local.namespace}/secrets/${each.key}"
    type     = "SecureString"
    value    = each.value
}