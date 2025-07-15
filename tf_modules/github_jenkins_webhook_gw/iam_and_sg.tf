locals {

  lambda_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  jwg_iam_roles = {
    "jgw_auth_lambda" : {
      name         = "${var.name}_jwg_auth_lambda"
      trust_policy = local.lambda_trust_policy
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
        "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
      ]
    }
  }

  jwg_sgs = {
    "jwg_auth_lambda" : {
      name = "${var.name}_jwg_auth_lambda"
    }
  }


  jwg_sg_rules = {
    "jwg_auth_lambda_access_to_jenkins" : {
      from_port                = 443
      to_port                  = 443
      source_security_group_id = aws_security_group.jwg_sgs["jwg_auth_lambda"].id
      sg_id                    = var.jenkins_server_sg_id
      description              = "${var.name}_jwg_auth_lambda_access_to_jenkins"

    }
  }
}


resource "aws_security_group" "jwg_sgs" {
  for_each = local.jwg_sgs
  name     = each.value.name
  vpc_id   = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "jwg_sg_rules" {
  for_each                 = local.jwg_sg_rules
  type                     = try(each.value.type, "ingress")
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = try(each.value.protocol, "tcp")
  cidr_blocks              = try(each.value.cidr_blocks, null)
  source_security_group_id = try(each.value.source_security_group_id, null)
  security_group_id        = each.value.sg_id
  description              = try(each.value.description, null)
}

resource "aws_iam_role" "jwg_iam_roles" {
  for_each            = local.jwg_iam_roles
  name                = each.value.name
  managed_policy_arns = try(each.value.managed_policy_arns, null)
  assume_role_policy  = each.value.trust_policy

  dynamic "inline_policy" {
    for_each = lookup(each.value, "inline_policy", null) != null ? [each.value] : []
    content {
      name   = try(inline_policy.value.name, "inline_policy")
      policy = inline_policy.value.policy
    }
  }
}