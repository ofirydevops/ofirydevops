resource "github_repository_webhook" "github_jenkins_webhook" {
  repository = var.git_repo
  configuration {
    url          = "https://${aws_route53_record.jenkins_gh_webhook.fqdn}/${local.api_rest_gateways["jenkins_webhook_gw"].resource_path}"
    content_type = "json"
    insecure_ssl = false
    secret = var.github_jenkins_webhook_secret
  }
  events = [
    "pull_request",
    "push",
    "issue_comment"
  ]
  active = true
}
