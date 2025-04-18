locals {

    github_metadata_url = "https://api.github.com/meta"
    github_webhook_cidrs = jsondecode(data.http.github_metadata.response_body)["hooks"]

    github_webhooks_v4_cidrs = [
        for cidr in local.github_webhook_cidrs: cidr if !strcontains(cidr, ":")
        ]
    github_webhooks_v6_cidrs = [
        for cidr in local.github_webhook_cidrs: cidr if strcontains(cidr, ":")
        ]
}

data "http" "github_metadata" {
  url = local.github_metadata_url
}

resource "aws_wafv2_ip_set" "github_ipv4" {
  name               = "${var.name}_github_ipv4"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = local.github_webhooks_v4_cidrs

  tags = {
    Name = "${var.name}_github_ipv4"
  }
}

resource "aws_wafv2_ip_set" "github_ipv6" {
  name               = "${var.name}_github_ipv6"
  scope              = "REGIONAL"
  ip_address_version = "IPV6"
  addresses          = local.github_webhooks_v6_cidrs

  tags = {
    Name = "${var.name}_github_ipv6"
  }
}


resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name}_jenkins_webhook_gw"
  scope       = "REGIONAL"

  default_action {
    block {}
  }


  dynamic "rule" {

    for_each = [
        "AWSManagedRulesAmazonIpReputationList",
        "AWSManagedRulesAnonymousIpList",
        "AWSManagedRulesCommonRuleSet",
        "AWSManagedRulesKnownBadInputsRuleSet",
        "AWSManagedRulesAdminProtectionRuleSet",
    ]
        content {
            name     = rule.value
            priority = rule.key

            override_action {
              count {}
            }

            statement {
                managed_rule_group_statement {

                    name = rule.value
                    vendor_name = "AWS"

                }
            }

            visibility_config {
            cloudwatch_metrics_enabled = false
            metric_name                = "${var.name}_${rule.value}_waf_metric"
            sampled_requests_enabled   = false
            }
        }  
    }




  rule {
    name     = "github_webhook_ipv4"
    priority = 6

    action {
      allow {}
    }

    statement {
        ip_set_reference_statement {
            arn = aws_wafv2_ip_set.github_ipv4.arn

      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.name}_github_webhook_ipv4_waf_metric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "github_webhook_ipv6"
    priority = 7

    action {
      allow {}
    }

    statement {
        ip_set_reference_statement {
            arn = aws_wafv2_ip_set.github_ipv6.arn

      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.name}_github_webhook_ipv6_waf_metric"
      sampled_requests_enabled   = false
    }
  }


  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.name}_jenkins_webhook_gw_waf"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl_association" "jgw" {
  resource_arn = aws_api_gateway_stage.stages["jenkins_webhook_gw"].arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}