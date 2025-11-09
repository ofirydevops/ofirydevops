locals {
  github_jenkins_webhook_secret = random_password.github_jenkins_webhook_secret.result
}

resource "random_password" "github_jenkins_webhook_secret" {
  length  = 32
  special = true
}

resource "github_repository_webhook" "github_jenkins_webhook" {
  for_each   = toset(nonsensitive(var.github_repos))
  repository = each.key
  configuration {
    url          = local.api_gw_url
    content_type = "json"
    insecure_ssl = false
    secret       = local.github_jenkins_webhook_secret
  }
  events = [
    "pull_request",
    "push",
    "issue_comment"
  ]
  active = true
}
