locals {
    secrets = yamldecode(file("${path.module}/../../secrets.yaml"))
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))
    region = local.global_conf["region"]
    name = "ofirydevops"
    git_repository = "devops-project"

    lambdas = [
      {
        name = "webhook"
        tag  = "v6.3.0"
      },
      {
        name = "runners"
        tag  = "v6.3.0"
      },
      {
        name = "runner-binaries-syncer"
        tag  = "v6.3.0"
      },
      {
        name = "ami-housekeeper"
        tag  = "v6.3.0"
      },
      {
        name = "termination-watcher"
        tag  = "v6.3.0"
      }
    ]
}


module "github_runners_s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "v4.6.0"
  bucket = "ofirydevops-github-aws-runners"
}

resource "aws_s3_object" "lambdas_zips" {
  depends_on = [module.download_lambda]
  for_each = toset([for lambda in local.lambdas : lambda.name])
  key        = "${each.key}.zip"
  bucket     = module.github_runners_s3_bucket.s3_bucket_id
  source     = "${each.key}.zip"
}

module "download_lambda" {
  source = "github-aws-runners/github-runner/aws//modules/download-lambda"
  version = "v6.3.0"
  lambdas = local.lambdas
}



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  depends_on = [ 
    module.download_lambda 
  ]

  name = "${local.name}_vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${local.region}a", "${local.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_dns_hostnames    = true
  enable_nat_gateway      = true
  map_public_ip_on_launch = false
  single_nat_gateway      = true
}

resource "random_id" "random" {
  byte_length = 20
}

module "runners" {
  source = "github-aws-runners/github-runner/aws//modules/multi-runner"

  version = "v6.3.0"

  lambda_s3_bucket = module.github_runners_s3_bucket.s3_bucket_id
  syncer_lambda_s3_key = aws_s3_object.lambdas_zips["runner-binaries-syncer"].key
  webhook_lambda_s3_key = aws_s3_object.lambdas_zips["webhook"].key
  runners_lambda_s3_key = aws_s3_object.lambdas_zips["runners"].key

  aws_region = local.region
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  prefix = local.name
  tags = {
    Name = local.name
  }
  github_app = {
    key_base64     = base64encode(file("${path.module}/../awsgithubrunner.secret.privatekey.pem"))
    id             = local.secrets["aws_github_runner_app_id"]
    webhook_secret = local.secrets["github_runner_webhook_secret"]
  }
  eventbridge = {
    enable = false
  }

  enable_ami_housekeeper = false

  instance_termination_watcher = {
    enable = false
  }
  multi_runner_config = {
    "linux_arm64" = {
      matcherConfig : {
        labelMatchers = [["self-hosted", "linux", "arm64", "kuku"]]
        exactMatch    = true
      }
      runner_config = {
        runner_os                      = "linux"
        runner_architecture            = "arm64"
        runner_extra_labels            = ["kuku"]
        enable_ssm_on_runners          = true

        scale_up_reserved_concurrent_executions = -1
        runner_disable_default_labels           = false
        create_service_linked_role_spot         = true
        enable_organization_runners             = false
        instance_types                          = ["t4g.large"]
        delay_webhook_event                     = 5
        runners_maximum_count                   = 2
        scale_down_schedule_expression          = "cron(* * * * ? *)"
        enable_userdata                         = true
        runner_name_prefix                      = "${local.name}_arm64_"
        ami_id_ssm_parameter_name               = "githubRunner30GBArm64AmiId"
      }
    },
    "linux_x64" = {
      matcherConfig : {
        labelMatchers = [["self-hosted", "linux", "x64", "kuku"]]
        exactMatch    = true
      }
      runner_config = {
        runner_os                       = "linux"
        runner_architecture             = "x64"
        runner_extra_labels             = ["kuku"]
        enable_ssm_on_runners           = true

        scale_up_reserved_concurrent_executions = -1
        runner_disable_default_labels           = false
        create_service_linked_role_spot         = true
        enable_organization_runners             = false
        instance_types                          = ["t3.large"]
        delay_webhook_event                     = 5
        runners_maximum_count                   = 2
        scale_down_schedule_expression          = "cron(* * * * ? *)"
        runner_name_prefix                      = "${local.name}_x64_"
        ami_id_ssm_parameter_name               = "githubRunner30GBAmd64AmiId"
        enable_userdata                         = false
      }
    }
  }
}


resource "github_repository_webhook" "aws_runners" {
  repository = local.git_repository
  configuration {
    url          = module.runners.webhook.endpoint
    content_type = "json"
    insecure_ssl = false
    secret = local.secrets["github_runner_webhook_secret"]
  }

  active = true

  events = ["workflow_job"]
}
