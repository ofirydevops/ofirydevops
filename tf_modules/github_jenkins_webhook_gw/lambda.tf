locals {
    requirements_filename = "requierments.txt"


    lambdas = {
        "gh_jenkins_webhook_auth" = {
            source_dir      = "${path.module}/jwg_auth_lambda"
            output_zip_path = "${timestamp()}-jwg_auth_lambda.zip"
            function_name   = "${var.name}_gh_jenkins_webhook_auth"
            role_arn        = aws_iam_role.jwg_iam_roles["jgw_auth_lambda"].arn
            handler         = "app.lambda_handler"
            runtime         = "python3.10"
            handler_file    = "app.py"
            sg_ids          = [aws_security_group.jwg_sgs["jwg_auth_lambda"].id]
            subnet_ids      = [var.jenkins_server_subnet_id]
            env_vars        = {
                GITHUB_WEBHOOK_SECRET = var.github_jenkins_webhook_secret
                JENKINS_URL = "https://${var.jenkins_server_private_ip}"
            }
        }
    }
}

resource "null_resource" "lambda_packages_installation" {
    for_each = local.lambdas
    triggers = {
        always = timestamp()
    }

    provisioner "local-exec" {
      command = "pip3.10 install --target ${each.value.source_dir}/tmp/ -r ${each.value.source_dir}/${local.requirements_filename} && cp ${each.value.source_dir}/${each.value.handler_file} ${each.value.source_dir}/tmp/"
    }
}

data "archive_file" "lambda_zips" {
    for_each = local.lambdas
    type = "zip"
    source_dir = "${each.value.source_dir}/tmp"
    output_path = each.value.output_zip_path
    depends_on = [ 
        null_resource.lambda_packages_installation
    ]
}

resource "aws_lambda_function" "lambdas" {
    for_each         = local.lambdas
    filename         = each.value.output_zip_path
    function_name    = each.value.function_name
    role             = each.value.role_arn
    handler          = each.value.handler
    source_code_hash = data.archive_file.lambda_zips[each.key].output_base64sha256
    runtime          = each.value.runtime
    environment {
        variables = each.value.env_vars
    }
    vpc_config {
      subnet_ids         = each.value.subnet_ids
      security_group_ids = each.value.sg_ids
    }
}