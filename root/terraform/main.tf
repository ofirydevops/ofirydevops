data "aws_availability_zones" "azs" {}

locals {
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))

    secrets = yamldecode(file("${path.module}/../../secrets.yaml"))["secrets"]

    root_jenkins_volume_az = data.aws_availability_zones.azs.names[0]

    region  = local.global_conf["region"]
    profile = local.global_conf["profile"]
    domain  = local.global_conf["domain"]
    ecr_repos = [
        "data_science_docker_cache"
    ]
    ssm_params = {
        "hosted_zone_id" : {
            key = "hostedZoneId"
            value = aws_route53_zone.main.zone_id
        }
        "main_key_pair_name" : {
            key = "mainKeyPairName"
            value = aws_key_pair.main.id
        }

        "root_jenkins_volume_az" : {
            key = "rootJenkinsVolumeAz"
            value = local.root_jenkins_volume_az
        }

        "root_jenkins_volume_id" : {
            key = "rootJenkinsVolumeId"
            value = aws_ebs_volume.root_jenkins.id
        }
        "data_science_cache_repo" : {
            key = "dataScienceCacheRepo"
            value = aws_ecr_repository.ecr_repos["data_science_docker_cache"].name
        }
    }
    buckets = {}
}


module "s3_buckets" {
  for_each = local.buckets
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "v4.6.0"
  bucket = each.key
}
resource "aws_route53_zone" "main" {
  name = local.domain
}

resource "aws_key_pair" "main" {
  key_name   = "main"
  public_key = local.secrets["main_ssh_key_pair_public_key"]
}


resource "aws_ebs_volume" "root_jenkins" {
  availability_zone = local.root_jenkins_volume_az
  size              = 20
  tags = {
    Name = "root_jenkins_volume_v3"
  }
}

resource "aws_ecr_repository" "ecr_repos" {
    for_each = toset(local.ecr_repos)
    name     = each.key
    image_tag_mutability = "MUTABLE"
    force_delete = true
}

resource "aws_ecr_lifecycle_policy" "ecr_repos" {
    for_each = toset(local.ecr_repos)
    repository = aws_ecr_repository.ecr_repos[each.key].name
    policy = templatefile("${path.module}/ecr_lifecycle_policy.json", {
      cache_image_tag_prefix = local.global_conf["cache_image_tag_prefix"]
    })
}

resource "aws_ssm_parameter" "params" {
    for_each = local.ssm_params
    name     = each.value.key
    type     = try(each.value.type, "String")
    value    = each.value.value
}

resource "aws_ssm_parameter" "secrets" {
    for_each = local.secrets
    name     = "/secrets/${each.key}"
    type     = "SecureString"
    value    = each.value
}