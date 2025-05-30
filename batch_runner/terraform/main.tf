data "aws_ssm_parameter" "params" {
  for_each = toset(local.ssm_params_to_read)
  name     = each.key
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "subnet" {
  availability_zone = local.ssm["rootJenkinsVolumeAz"]
  vpc_id = local.default_vpc_id
}

locals {

    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))

    ssm_params_to_read = [
      "rootJenkinsVolumeAz",
      "rootJenkinsKeyPair",
      "basic100GBAmd64AmiId",
      "basic100GBArm64AmiId",
      "batchGpu100GBAmd64AmiId"
    ]
    ssm = { for name in local.ssm_params_to_read : name => data.aws_ssm_parameter.params[name].value }

    default_vpc_id = data.aws_vpc.default.id
    subnet_id      = data.aws_subnet.subnet.id

    image_tag_prefix       = "batch_"
    batch_artifacts_s3_dir = "batch_artifacts"

    s3_buckets = {
        "batch_runner" : {
            name           = "ofirydevops-batch-runner"
            lifecycle_rule = [
                {
                    id         = "delete-batch-artifacts-after-30-days"
                    enabled    = true
                    filter = {
                        prefix = "${local.batch_artifacts_s3_dir}/"
                    }
                    expiration = {
                        days = 30
                    }
                }
            ]
        }
    }

    batch_envs = {
        main_arm64 = {
            name                   = "main_arm64"
            instance_role          = aws_iam_instance_profile.iam_profiles["main_batch_worker"].arn
            ec2_key_pair           = local.ssm["rootJenkinsKeyPair"]
            instance_type          = ["c6g.2xlarge"]
            max_vcpus              = 10
            min_vcpus              = 0
            security_group_ids     = [aws_security_group.sgs["main_batch_worker"].id]
            subnets                = [local.subnet_id]
            compute_resources_type = "SPOT"
            image_id_override      = local.ssm["basic100GBArm64AmiId"]
            image_type             = "ECS_AL2023"
            allocation_strategy    = "BEST_FIT_PROGRESSIVE"
            vcpus_per_childjob     = 2
            memory_mb_per_childjob = 4000
        }

        main_amd64 = {
            name                   = "main_amd64"
            instance_role          = aws_iam_instance_profile.iam_profiles["main_batch_worker"].arn
            ec2_key_pair           = local.ssm["rootJenkinsKeyPair"]
            instance_type          = ["c6a.2xlarge"]
            max_vcpus              = 10
            min_vcpus              = 0
            security_group_ids     = [aws_security_group.sgs["main_batch_worker"].id]
            subnets                = [local.subnet_id]
            compute_resources_type = "SPOT"
            image_id_override      = local.ssm["basic100GBAmd64AmiId"]
            image_type             = "ECS_AL2023"
            allocation_strategy    = "BEST_FIT_PROGRESSIVE"
            vcpus_per_childjob     = 2
            memory_mb_per_childjob = 4000
        }

        gpu_amd64 = {
            name                   = "gpu_amd64"
            instance_role          = aws_iam_instance_profile.iam_profiles["main_batch_worker"].arn
            ec2_key_pair           = local.ssm["rootJenkinsKeyPair"]
            instance_type          = ["g4dn.xlarge"]
            max_vcpus              = 10
            min_vcpus              = 0
            security_group_ids     = [aws_security_group.sgs["main_batch_worker"].id]
            subnets                = [local.subnet_id]
            compute_resources_type = "EC2"
            image_id_override      = local.ssm["batchGpu100GBAmd64AmiId"]
            image_type             = "ECS_AL2_NVIDIA"
            allocation_strategy    = "BEST_FIT_PROGRESSIVE"
            vcpus_per_childjob     = 1
            memory_mb_per_childjob = 7000
            compose_service        = "gpu"
        }
    }
}

resource "aws_batch_compute_environment" "batch_envs" {
    depends_on = [ 
        null_resource.child_wrapper_images_docker_build_and_push
    ]

    for_each                 = local.batch_envs
    compute_environment_name = each.value.name
    service_role             = aws_iam_service_linked_role.batch.id
    type                     = "MANAGED"

    compute_resources {
        instance_role       = each.value.instance_role
        ec2_key_pair        = try(each.value.ec2_key_pair, null)
        instance_type       = each.value.instance_type
        max_vcpus           = each.value.max_vcpus
        min_vcpus           = each.value.min_vcpus
        security_group_ids  = try(each.value.security_group_ids, [])
        subnets             = each.value.subnets
        type                = try(each.value.compute_resources_type, "EC2")
        allocation_strategy = try(each.value.allocation_strategy, null)
        tags                = {
            Name = "batch_runner_${each.value.name}"
        }

        dynamic "ec2_configuration"  {

            for_each = can(each.value.image_id_override) ? [each.value] : []

            content {
                image_id_override = ec2_configuration.value.image_id_override
                image_type = try(ec2_configuration.value.image_type, "ECS_AL2023")
            }
        }
    }
}

resource "aws_batch_job_queue" "queues" {
    for_each = local.batch_envs
    name     = each.value.name
    state    = "ENABLED"
    priority = 1

    compute_environment_order {
        order               = 1
        compute_environment = aws_batch_compute_environment.batch_envs[each.key].arn
    }
}


resource "aws_ssm_parameter" "batch_config_params" {
    for_each = local.batch_envs
    name     = "/batch_runner_conf/${each.value.name}"
    type     = "String"
    value    = jsonencode({
        batch_job_queue_arn    = aws_batch_job_queue.queues[each.key].arn
        region                 = local.global_conf["region"]
        profile                = local.global_conf["profile"]
        bucket                 = module.s3_buckets["batch_runner"].s3_bucket_id
        ecr_repo_url           = aws_ecr_repository.ecr_repos[each.key].repository_url
        image_tag_prefix       = local.image_tag_prefix
        batch_artifacts_s3_dir = local.batch_artifacts_s3_dir
        vcpus_per_childjob     = each.value.vcpus_per_childjob
        memory_mb_per_childjob = each.value.memory_mb_per_childjob
        child_wrapper_image    = local.child_wrapper_image
        compose_service        = try(each.value.compose_service, "standard")
    })
}

module "s3_buckets" {
    for_each       = local.s3_buckets
    source         = "terraform-aws-modules/s3-bucket/aws"
    version        = "v4.6.0"
    bucket         = each.value.name
    lifecycle_rule = try(each.value.lifecycle_rule, null)
    force_destroy = true
}

resource "aws_ecr_repository" "ecr_repos" {
    for_each             = local.batch_envs
    name                 = "batch_runner_${each.value.name}"
    image_tag_mutability = "MUTABLE"
    force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "ecr_repos" {
    for_each                 = local.batch_envs
    repository               = aws_ecr_repository.ecr_repos[each.key].name
    policy                   = templatefile("${path.module}/ecr_lifecycle_policy.json", {
      tag_prefix             = local.image_tag_prefix
    })
}