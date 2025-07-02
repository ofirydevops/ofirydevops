data "aws_caller_identity" "current" {}

locals {
    aws_github_runner_webhook_secret = random_password.aws_github_runner_webhook_secret.result

    prefix = "${var.namespace}-gh"

    multi_runner_config_files = {
      for c in fileset(var.runner_configs_dir_abs_path, "*.yaml") :

      trimsuffix(c, ".yaml") => yamldecode(templatefile("${var.runner_configs_dir_abs_path}/${c}", { namespace = var.namespace }))
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
            scale_down_schedule_expression          = "cron(0/5 * * * ? *)"
            enable_userdata                         = true
            block_device_mappings                   = []
            instance_target_capacity_type           = "spot"
            runner_iam_role_managed_policy_arns     = local.runner_iam_role_managed_policy_arns
            userdata_content                        = local.userdata_content
            runner_metadata_options                 = local.runner_metadata_options
          }, cfg.runner_config,
          {
            ami = contains(keys(cfg.runner_config), "ami") ? merge(
              cfg.runner_config.ami,
              {
                id_ssm_parameter_arn = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${trimprefix(cfg.runner_config.ami.id_ssm_parameter_name, "/")}"
              }
            ) : null
          }
          )
        })
      }
    ]...)

    userdata_content       = templatefile("${path.module}/userdata.sh", {
      default_profile_name = var.profile
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
  

    account_id       = data.aws_caller_identity.current.account_id
    region           = var.region
    profile          = var.profile

    ecr_registry_url     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"

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
      "gh_runner_general" : {
          name   = "${var.namespace}_gh_runner_general"
          policy = jsonencode({
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
                        "batch:*",
                        "codeartifact:*",
                        "sts:*",
                        "route53:*",
                        "wafv2:*",
                        "acm:*"
                        ]
                    Effect   = "Allow"
                    Resource = "*"
                }
            ]
        })
      }
    }

    sgs = {
      "gh_runner_general" : {
        name = "${var.namespace}_gh_runner_general"
      }
    }
}

resource "aws_security_group" "sgs" {
  for_each = local.sgs
  name        = each.value.name
  vpc_id      = var.vpc_id
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
  cidr_blocks       = ["${var.local_workstation_pub_ip}/32"]
  security_group_id = aws_security_group.sgs["gh_runner_general"].id
}
resource "aws_security_group_rule" "remote_dev_access_to_runners" {
  type              = "ingress"
  from_port         = 5000
  to_port           = 5000
  protocol          = "tcp"
  cidr_blocks       = ["${var.local_workstation_pub_ip}/32"]
  security_group_id = aws_security_group.sgs["gh_runner_general"].id
}

resource "aws_iam_policy" "gh_runner_policies" {
  for_each = local.iam_policies
  name     = each.value.name
  policy   = each.value.policy
}

module "github_runners_s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "v4.6.0"
  bucket = "${var.namespace}-github-aws-runners"
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


module "runners" {
  source  = "github-aws-runners/github-runner/aws//modules/multi-runner"
  version = "v6.5.6"

  lambda_s3_bucket      = module.github_runners_s3_bucket.s3_bucket_id
  syncer_lambda_s3_key  = aws_s3_object.lambdas_zips["runner-binaries-syncer"].key
  webhook_lambda_s3_key = aws_s3_object.lambdas_zips["webhook"].key
  runners_lambda_s3_key = aws_s3_object.lambdas_zips["runners"].key
  runner_additional_security_group_ids = [
    aws_security_group.sgs["gh_runner_general"].id
  ]

  aws_region = local.region
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids
  prefix     = local.prefix
  key_name   = var.keypair_name
  associate_public_ipv4_address = true

  multi_runner_config = local.multi_runner_config

  tags = {
    Name = local.prefix
  }
  github_app = {
    key_base64     = base64encode(var.aws_github_runner_app_private_key)
    id             = var.aws_github_runner_app_id
    webhook_secret = local.aws_github_runner_webhook_secret
  }
  eventbridge = {
    enable = false
  }

  enable_ami_housekeeper = false
  instance_termination_watcher = {
    enable = false
  }
}

resource "random_password" "aws_github_runner_webhook_secret" {
  length  = 32
  special = false
}

resource "null_resource" "cleanup" {
  depends_on = [module.runners]

  provisioner "local-exec" {
    command = "rm *.zip || true"
  }
}
