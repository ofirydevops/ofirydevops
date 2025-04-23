data "aws_availability_zones" "azs" {}

locals {
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))

    secrets = yamldecode(file("${path.module}/../../secrets.yaml"))

    root_jenkins_volume_az = data.aws_availability_zones.azs.names[0]

    region = local.global_conf["region"]
    domain = local.global_conf["domain"]
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

        "root_jenkins_volume_az" : {
            key = "rootJenkinsVolumeAz"
            value = local.root_jenkins_volume_az
        }

        "root_jenkins_volume_id" : {
            key = "rootJenkinsVolumeId"
            value = aws_ebs_volume.root_jenkins.id
        }
        "root_jenkins_private_key" : {
            key = "/secrets/rootJenkinsPrivateKey"
            value = file("${path.module}/../key_pair/root_jenkins.secret.key")
            type = "SecureString"
        }
        "github_runner_app_private_key" : {
            key = "/secrets/githubRunnerAppPrivateKey"
            value = file("${path.module}/../../github_aws_runners/awsgithubrunner.secret.privatekey.pem")
            type = "SecureString"
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

resource "aws_key_pair" "root_jenkins" {
  key_name   = "root_jenkins"
  public_key = file("${path.module}/../key_pair/root_jenkins.pub")
}

resource "aws_ebs_volume" "root_jenkins" {
  availability_zone = local.root_jenkins_volume_az
  size              = 20
  tags = {
    Name = "root_jenkins_volume_v3"
  }
}

resource "aws_ssm_parameter" "params" {
    for_each = local.ssm_params
    name     = each.value.key
    type     = try(each.value.type, "String")
    value    = each.value.value
}

resource "aws_ssm_parameter" "more_secrets" {
    for_each = local.secrets
    name     = "/secrets/${each.key}"
    type     = "SecureString"
    value    = each.value
}