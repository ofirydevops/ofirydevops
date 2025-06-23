locals {

    ecr_repos = {
        "python_env_docker_cache" : {
            name = "${var.namespace}_python_env_docker_cache"
            ssm_param = "/${var.namespace}/ecr_repo/python_env_docker_cache"
        }

    }

    cache_image_tag_prefix = "cache_hash_"

}

resource "aws_ecr_repository" "ecr_repos" {
    for_each             = local.ecr_repos
    name                 = each.value.name
    image_tag_mutability = "MUTABLE"
    force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "ecr_repos" {
    for_each                 = local.ecr_repos
    repository               = aws_ecr_repository.ecr_repos[each.key].name
    policy                   = templatefile("${path.module}/ecr_lifecycle_policy.json", {
      cache_image_tag_prefix = local.cache_image_tag_prefix
    })
}

resource "aws_ssm_parameter" "ecr_repos" {
    for_each = local.ecr_repos
    name     = each.value.ssm_param 
    type     = "String"
    value    = aws_ecr_repository.ecr_repos[each.key].name
}

resource "aws_ssm_parameter" "cache_image_tag_prefix" {
    name     = "/${var.namespace}/python_env_runner/cache_image_prefix"
    type     = "String"
    value    = local.cache_image_tag_prefix
}