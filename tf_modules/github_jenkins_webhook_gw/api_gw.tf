data "aws_route53_zone" "domain_data" {
  count = var.route53_domain == null ? 0 : 1
  name  = var.route53_domain
}

locals {
  name           = "${var.name}_jenkins_webhook_gw"
  endpoint_types = ["REGIONAL"]
  stage_name     = "main"
  resource_path  = "github_webhook"

  domain_name            = var.route53_domain == null ? null : "${var.name}jgw.${var.route53_domain}"
  route53_hosted_zone_id = var.route53_domain == null ? null : data.aws_route53_zone.domain_data[0].zone_id
  api_gw_url             = var.route53_domain == null ? "${aws_api_gateway_stage.stage.invoke_url}/${local.resource_path}" : "https://${aws_route53_record.jenkins_gh_webhook[0].fqdn}/${local.resource_path}"
}


resource "aws_api_gateway_rest_api" "api_rest_gateway" {
  name     = local.name
  endpoint_configuration {
    types = local.endpoint_types
  }
}


resource "aws_api_gateway_resource" "gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_rest_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_rest_gateway.root_resource_id
  path_part   = local.resource_path
}

resource "aws_api_gateway_request_validator" "validator" {
  name                        = local.name
  rest_api_id                 = aws_api_gateway_rest_api.api_rest_gateway.id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id          = aws_api_gateway_rest_api.api_rest_gateway.id
  resource_id          = aws_api_gateway_resource.gateway_resource.id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validator.id
}

resource "aws_api_gateway_integration" "integrations" {
  rest_api_id             = aws_api_gateway_rest_api.api_rest_gateway.id
  resource_id             = aws_api_gateway_resource.gateway_resource.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambdas["gh_jenkins_webhook_auth"].invoke_arn
}

resource "aws_lambda_permission" "auth_lambda_permission" {
  statement_id  = "allow_to_invoke_auth_lambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambdas["gh_jenkins_webhook_auth"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_rest_gateway.execution_arn}/*/POST/${local.resource_path}"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_rest_gateway.id
  triggers = {
    always_run = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_api_gateway_integration.integrations,
    aws_route53_record.acm_validation_dns
  ]
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api_rest_gateway.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = local.stage_name
}

resource "aws_acm_certificate" "api_gw" {
  count = var.route53_domain == null ? 0 : 1
  domain_name       = local.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_record" "acm_validation_dns" {
  count = var.route53_domain == null ? 0 : 1
  zone_id = local.route53_hosted_zone_id
  name    = tolist(aws_acm_certificate.api_gw[0].domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.api_gw[0].domain_validation_options)[0].resource_record_type
  ttl     = 300
  records = [
    tolist(aws_acm_certificate.api_gw[0].domain_validation_options)[0].resource_record_value
  ]
}
resource "aws_apigatewayv2_domain_name" "domain" {
  count = var.route53_domain == null ? 0 : 1
  domain_name = local.domain_name
  domain_name_configuration {
    certificate_arn = aws_acm_certificate.api_gw[0].arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
  depends_on = [
    aws_route53_record.acm_validation_dns
  ]
}

resource "aws_apigatewayv2_api_mapping" "mapping" {
  count = var.route53_domain == null ? 0 : 1
  domain_name = aws_apigatewayv2_domain_name.domain[0].id
  api_id      = aws_api_gateway_rest_api.api_rest_gateway.id
  stage       = split("-", aws_api_gateway_stage.stage.id)[2]
}

resource "aws_route53_record" "jenkins_gh_webhook" {
  count = var.route53_domain == null ? 0 : 1
  zone_id = local.route53_hosted_zone_id
  name    = aws_apigatewayv2_domain_name.domain[0].domain_name
  type    = "A"
  alias {
    name                   = aws_apigatewayv2_domain_name.domain[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.domain[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}