locals {
  github_jenkins_webhook_secret = random_password.github_jenkins_webhook_secret.result
}

resource "random_password" "github_jenkins_webhook_secret" {
  length  = 32
  special = true
}

resource "github_repository_webhook" "github_jenkins_webhook" {
  repository = var.github_repo
  configuration {
    url          = "https://${aws_route53_record.jenkins_gh_webhook.fqdn}/${local.api_rest_gateways["jenkins_webhook_gw"].resource_path}"
    content_type = "json"
    insecure_ssl = false
    secret = local.github_jenkins_webhook_secret
  }
  events = [
    "pull_request",
    "push",
    "issue_comment"
  ]
  active = true
}
