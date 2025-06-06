data "aws_caller_identity" "current" {}
data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com"
}

data "aws_ssm_parameter" "params" {
  for_each = toset(local.ssm_params_to_read)
  name     = each.value
}

locals {
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))

    prefix = "ghrunner"

    multi_runner_config_files = {
      for c in fileset("${path.module}/runner_configs", "*.yaml") :

      trimsuffix(c, ".yaml") => yamldecode(file("${path.module}/runner_configs/${c}"))
    }

    multi_runner_config = merge([
      for runner_config_filename, data in local.multi_runner_config_files : {
        for runner_name, cfg in data :
        "${runner_config_filename}_${runner_name}" => merge(cfg,
        {

          matcherConfig = merge({
            exactMatch = true
            labelMatchers = [
              [ "self-hosted", runner_name ]
            ]
          }, try(cfg.matcherConfig, {}))

          runner_config = merge(
          {
            runner_name_prefix                      = "${local.prefix}_${runner_name}"
            runner_ec2_tags                         = { "Name" : "${local.prefix}_${runner_name}" }
            runner_os                               = "linux"
            runner_extra_labels                     = []
            enable_ssm_on_runners                   = true
            scale_up_reserved_concurrent_executions = -1
            runner_disable_default_labels           = false
            create_service_linked_role_spot         = true
            enable_organization_runners             = false
            delay_webhook_event                     = 5
            runners_maximum_count                   = 2
            scale_down_schedule_expression          = "cron(* * * * ? *)"
            enable_userdata                         = true
            block_device_mappings                   = []
            instance_target_capacity_type           = "spot"
            runner_iam_role_managed_policy_arns     = local.runner_iam_role_managed_policy_arns
            userdata_content                        = local.userdata_content
            runner_metadata_options                 = local.runner_metadata_options
          }, cfg.runner_config)
        })
      }
    ]...)

    userdata_content       = templatefile("${path.module}/userdata.sh", {
      default_profile_name = local.global_conf["profile"]
    })
    runner_iam_role_managed_policy_arns = [
      aws_iam_policy.gh_runner_policies["gh_runner_general"].arn
    ]
    runner_metadata_options       = {
        instance_metadata_tags      = "enabled"
        http_endpoint               = "enabled"
        http_tokens                 = "optional"
        http_put_response_hop_limit = 1
      }
  
    ssm = { for name in local.ssm_params_to_read : name => data.aws_ssm_parameter.params[name].value }

    account_id        = data.aws_caller_identity.current.account_id
    region            = local.global_conf["region"]
    profile           = local.global_conf["profile"]
    git_repository    = local.global_conf["git_repo"]
    laptop_public_ip  = trimspace(data.http.my_public_ip.response_body)

    ecr_registry_url = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"
    gh_actions_variables = {
      AWS_ECR_REGISTRY             = local.ecr_registry_url
      AWS_DEFAULT_PROFILE          = local.global_conf["profile"]
      AWS_REGION                   = local.region
      DOCKER_CONTAINER_DRIVER_NAME = "dc"
    }

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

    iam_policies = {
      "gh_runner_general" : jsonencode({
          Version = "2012-10-17"
          Statement = [
              {
                  Action = [
                      "ecr:*",
                      "ecs:*",
                      "ec2:*",
                      "autoscaling:*",
                      "iam:*",
                      "lambda:*",
                      "apigateway:*",
                      "sqs:*",
                      "cloudwatch:*",
                      "s3:*",
                      "ssm:*",
                      "logs:*",
                      "secretsmanager:*",
                      "events:*",
                      "route53:*",
                      "batch:*"
                      ]
                  Effect   = "Allow"
                  Resource = "*"
              }
          ]
      })
    }

    sgs = {
      "gh_runner_general" : {}
    }

    ssm_params_to_read = [
      "mainKeyPairName",
      "/secrets/aws_github_runner_app_private_key",
      "/secrets/aws_github_runner_app_id",
      "/secrets/aws_github_runner_webhook_secret",
      "/secrets/github_token"
    ]
}

resource "aws_security_group" "sgs" {
  for_each = local.sgs
  name        = each.key
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "laptop_ssh_access_to_runners" {
  for_each          = local.sgs
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${local.laptop_public_ip}/32"]
  security_group_id = aws_security_group.sgs["gh_runner_general"].id
}
resource "aws_security_group_rule" "remote_dev_access_to_runners" {
  type              = "ingress"
  from_port         = 5000
  to_port           = 5000
  protocol          = "tcp"
  cidr_blocks       = ["${local.laptop_public_ip}/32"]
  security_group_id = aws_security_group.sgs["gh_runner_general"].id
}

resource "aws_iam_policy" "gh_runner_policies" {
  for_each = local.iam_policies
  name     = each.key
  policy   = each.value
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

  name = "${local.prefix}_vpc"
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
  source  = "github-aws-runners/github-runner/aws//modules/multi-runner"
  version = "v6.3.0"

  lambda_s3_bucket      = module.github_runners_s3_bucket.s3_bucket_id
  syncer_lambda_s3_key  = aws_s3_object.lambdas_zips["runner-binaries-syncer"].key
  webhook_lambda_s3_key = aws_s3_object.lambdas_zips["webhook"].key
  runners_lambda_s3_key = aws_s3_object.lambdas_zips["runners"].key
  runner_additional_security_group_ids = [
    aws_security_group.sgs["gh_runner_general"].id
  ]

  aws_region = local.region
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  prefix     = local.prefix
  key_name   = local.ssm["mainKeyPairName"]
  associate_public_ipv4_address = true

  multi_runner_config = local.multi_runner_config

  tags = {
    Name = local.prefix
  }
  github_app = {
    key_base64     = base64encode(local.ssm["/secrets/aws_github_runner_app_private_key"])
    id             = local.ssm["/secrets/aws_github_runner_app_id"]
    webhook_secret = local.ssm["/secrets/aws_github_runner_webhook_secret"]
  }
  eventbridge = {
    enable = false
  }

  enable_ami_housekeeper = false
  instance_termination_watcher = {
    enable = false
  }
}


resource "github_repository_webhook" "aws_runners" {
  repository = local.git_repository
  configuration {
    url          = module.runners.webhook.endpoint
    content_type = "json"
    insecure_ssl = false
    secret = local.ssm["/secrets/aws_github_runner_webhook_secret"]
  }

  active = true

  events = ["workflow_job"]
}

resource "github_actions_variable" "vars" {
  for_each      = local.gh_actions_variables
  repository    = local.git_repository
  variable_name = each.key
  value         = each.value
}


resource "null_resource" "cleanup" {
  depends_on = [module.runners]

  provisioner "local-exec" {
    command = "rm *.zip || true"
  }
}