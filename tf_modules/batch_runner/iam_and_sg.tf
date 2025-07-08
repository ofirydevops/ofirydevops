locals {

  ec2_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  iam_roles = {
    "main_batch_worker" : {
      name                    = "${var.namespace}_main_batch_worker"
      assume_role_policy      = local.ec2_trust_policy
      create_instance_profile = true
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
      ]
      inline_policy = jsonencode({
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
              "events:*"
            ]
            Effect   = "Allow"
            Resource = "*"
          }
        ]
      })
    }
  }

  sgs = {
    "main_batch_worker" : {
      name = "${var.namespace}_main_batch_worker"
    }
  }

  sg_rules = {
    "ssh_access_to_batch_worker" : {
      from_port   = 22
      to_port     = 22
      cidr_blocks = ["${var.local_workstation_pub_ip}/32"]
      sg_id       = aws_security_group.sgs["main_batch_worker"].id
      description = "ssh_access_to_batch_worker"
    }
  }
}

resource "aws_iam_service_linked_role" "batch" {
  aws_service_name = "batch.amazonaws.com"
}


resource "aws_security_group" "sgs" {
  for_each = local.sgs
  name     = each.value.name
  vpc_id   = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "sg_rules" {
  for_each                 = local.sg_rules
  type                     = try(each.value.type, "ingress")
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = try(each.value.protocol, "tcp")
  cidr_blocks              = try(each.value.cidr_blocks, null)
  source_security_group_id = try(each.value.source_security_group_id, null)
  security_group_id        = each.value.sg_id
  description              = try(each.value.description, null)
}

resource "aws_iam_role" "iam_roles" {
  for_each            = local.iam_roles
  name                = each.value.name
  managed_policy_arns = try(each.value.managed_policy_arns, null)
  assume_role_policy  = each.value.assume_role_policy

  dynamic "inline_policy" {
    for_each = lookup(each.value, "inline_policy", null) != null ? [each.value] : []
    content {
      name   = "inline_policy"
      policy = inline_policy.value.inline_policy
    }
  }
}

resource "aws_iam_instance_profile" "iam_profiles" {
  for_each = { for k, v in local.iam_roles : k => v if try(v.create_instance_profile, false) }
  name     = each.value.name
  role     = aws_iam_role.iam_roles[each.key].name
}