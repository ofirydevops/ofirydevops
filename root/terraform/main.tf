locals {
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))

    region = local.global_conf["region"]
    ecr_repos = {
        "root_jenkins" : {}
    }

    ssm_params = {
        "hosted_zone_id" : {
            key = "hostedZoneId"
            value = aws_route53_zone.main.zone_id
        }
        "root_jenkins_key_pair" : {
            key = "rootJenkinsKeyPair"
            value = aws_key_pair.root_jenkins.id
        }
        "root_jenkins_ecr_repo_url" : {
            key = "rootJenkinsEcrRepoUrl"
            value = aws_ecr_repository.ecr_repos["root_jenkins"].repository_url
        }
    }
}

resource "aws_route53_zone" "main" {
  name = "ofirydevops.com"
}

resource "aws_key_pair" "root_jenkins" {
  key_name   = "root_jenkins"
  public_key = file("${path.module}/../key_pair/root_jenkins.pub")
}

resource "aws_ecr_repository" "ecr_repos" {
    for_each = local.ecr_repos
    name     = each.key
    image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_lifecycle_policy" "ecr_repos" {
    for_each = local.ecr_repos
    repository = aws_ecr_repository.ecr_repos[each.key].name
    policy = file("${path.module}/policies/ecr_lifecycle_policy.json")
}

resource "aws_ssm_parameter" "params" {
    for_each = local.ssm_params
    name     = each.value.key
    type     = "String"
    value    = each.value.value
}