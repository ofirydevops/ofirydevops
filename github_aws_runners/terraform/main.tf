locals {
    secrets = yamldecode(file("${path.module}/../../secrets.yaml"))
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))
    region = local.global_conf["region"]
    name = "github_aws_runners"
}

module "download_lambda" {
  source = "github-aws-runners/github-runner/aws//modules/download-lambda"
  version = "v6.3.0"
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
    }
  ]
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
  source = "github-aws-runners/github-runner/aws"
  version = "v6.3.0"

  create_service_linked_role_spot = true
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
    webhook_secret = random_id.random.hex
  }

  webhook_lambda_zip                = "${path.module}/../webhook.zip"
  runner_binaries_syncer_lambda_zip = "${path.module}/../runner-binaries-syncer.zip"
  runners_lambda_zip                = "${path.module}/../runners.zip"

  enable_organization_runners = false
  runner_extra_labels         = ["default", "example"]

  # enable access to the runners via SSM
  enable_ssm_on_runners = true

  instance_types = ["t3.xlarge"]

  delay_webhook_event   = 5
  runners_maximum_count = 2
  scale_down_schedule_expression = "cron(* * * * ? *)"
  enable_user_data_debug_logging_runner = true
  runner_name_prefix = "${local.name}_"
  eventbridge = {
    enable = false
  }

  enable_ami_housekeeper = true
  ami_housekeeper_cleanup_config = {
    ssmParameterNames = ["*/ami-id"]
    minimumDaysOld    = 10
    amiFilters = [
      {
        Name   = "name"
        Values = ["*al2023*"]
      }
    ]
  }

  instance_termination_watcher = {
    enable = true
  }
}

module "webhook_github_app" {
  source = "github-aws-runners/github-runner/aws//modules/webhook-github-app"
  version = "v6.3.0"

  depends_on = [module.runners]
  github_app = {
    key_base64     = base64encode(file("${path.module}/../awsgithubrunner.secret.privatekey.pem"))
    id             = local.secrets["aws_github_runner_app_id"]
    webhook_secret = random_id.random.hex
  }
  webhook_endpoint = module.runners.webhook.endpoint
}