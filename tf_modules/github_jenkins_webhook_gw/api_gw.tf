locals {
  api_rest_gateways = {
    "jenkins_webhook_gw" : {
      name           = "${var.name}_jenkins_webhook_gw"
      domain_name    = "${var.name}jgw.${var.domain}"
      endpoint_types = ["REGIONAL"]
      stage_name     = "main"
      resource_path  = "github_webhook"
    }
  }
}


resource "aws_api_gateway_rest_api" "api_rest_gateways" {
  for_each = local.api_rest_gateways
  name     = each.value.name
  endpoint_configuration {
    types = each.value.endpoint_types
  }
}


resource "aws_api_gateway_resource" "gateway_resources" {
  for_each    = local.api_rest_gateways
  rest_api_id = aws_api_gateway_rest_api.api_rest_gateways[each.key].id
  parent_id   = aws_api_gateway_rest_api.api_rest_gateways[each.key].root_resource_id
  path_part   = each.value.resource_path
}

resource "aws_api_gateway_request_validator" "validators" {
  for_each                    = local.api_rest_gateways
  name                        = each.key
  rest_api_id                 = aws_api_gateway_rest_api.api_rest_gateways[each.key].id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "post_methods" {
  for_each             = local.api_rest_gateways
  rest_api_id          = aws_api_gateway_rest_api.api_rest_gateways[each.key].id
  resource_id          = aws_api_gateway_resource.gateway_resources[each.key].id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validators[each.key].id
}

resource "aws_api_gateway_integration" "integrations" {
  for_each                = local.api_rest_gateways
  rest_api_id             = aws_api_gateway_rest_api.api_rest_gateways[each.key].id
  resource_id             = aws_api_gateway_resource.gateway_resources[each.key].id
  http_method             = aws_api_gateway_method.post_methods[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambdas["gh_jenkins_webhook_auth"].invoke_arn
}

resource "aws_acm_certificate" "api_gw" {
  domain_name       = local.api_rest_gateways["jenkins_webhook_gw"].domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_record" "acm_validation_dns" {
  zone_id = var.hosted_zone_id
  name    = tolist(aws_acm_certificate.api_gw.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.api_gw.domain_validation_options)[0].resource_record_type
  ttl     = 300
  records = [
    tolist(aws_acm_certificate.api_gw.domain_validation_options)[0].resource_record_value
  ]
}

resource "aws_lambda_permission" "auth_lambda_permission" {
  for_each      = local.api_rest_gateways
  statement_id  = "allow_${each.key}_to_invoke_auth_lambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambdas["gh_jenkins_webhook_auth"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_rest_gateways[each.key].execution_arn}/*/POST/${each.value.resource_path}"
}

resource "aws_api_gateway_deployment" "deployments" {
  for_each    = local.api_rest_gateways
  rest_api_id = aws_api_gateway_rest_api.api_rest_gateways[each.key].id
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

resource "aws_api_gateway_stage" "stages" {
  for_each      = local.api_rest_gateways
  rest_api_id   = aws_api_gateway_rest_api.api_rest_gateways[each.key].id
  deployment_id = aws_api_gateway_deployment.deployments[each.key].id
  stage_name    = each.value.stage_name
}

resource "aws_apigatewayv2_domain_name" "domains" {
  for_each    = local.api_rest_gateways
  domain_name = each.value.domain_name
  domain_name_configuration {
    certificate_arn = aws_acm_certificate.api_gw.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
  depends_on = [
    aws_route53_record.acm_validation_dns
  ]
}

resource "aws_apigatewayv2_api_mapping" "mappings" {
  for_each    = local.api_rest_gateways
  domain_name = aws_apigatewayv2_domain_name.domains[each.key].id
  api_id      = aws_api_gateway_rest_api.api_rest_gateways[each.key].id
  stage       = split("-", aws_api_gateway_stage.stages[each.key].id)[2]
}

resource "aws_route53_record" "jenkins_gh_webhook" {
  zone_id = var.hosted_zone_id
  name    = aws_apigatewayv2_domain_name.domains["jenkins_webhook_gw"].domain_name
  type    = "A"
  alias {
    name                   = aws_apigatewayv2_domain_name.domains["jenkins_webhook_gw"].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.domains["jenkins_webhook_gw"].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}