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
      "deepLearning100GBAmd64AmiId",
      "deepLearning100GBArm64AmiId"
    ]
    ssm = { for name in local.ssm_params_to_read : name => data.aws_ssm_parameter.params[name].value }

    default_vpc_id = data.aws_vpc.default.id
    subnet_id = data.aws_subnet.subnet.id

    batch_envs = {
        main_arm64 = {
            compute_environment_name = "main_arm64_batch_runner"
            instance_role            = aws_iam_instance_profile.iam_profiles["main_batch_worker"].arn
            ec2_key_pair             = local.ssm["rootJenkinsKeyPair"]
            instance_type            = ["c6g.xlarge"]
            max_vcpus                = 10
            min_vcpus                = 0
            security_group_ids       = [aws_security_group.sgs["main_batch_worker"].id]
            subnets                  = [local.subnet_id]
            compute_resources_type   = "SPOT"
            image_id_override        = local.ssm["basic100GBArm64AmiId"]
            image_type               = "ECS_AL2023"
            allocation_strategy      = "BEST_FIT_PROGRESSIVE"
        }
    }
}


resource "aws_batch_compute_environment" "batch_envs" {

    for_each                 = local.batch_envs
    compute_environment_name = each.value.compute_environment_name
    service_role             = aws_iam_role.iam_roles["aws_batch_service_role"].arn
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
    name     = each.value.compute_environment_name
    state    = "ENABLED"
    priority = 1

    compute_environment_order {
        order               = 1
        compute_environment = aws_batch_compute_environment.batch_envs[each.key].arn
    }
}
