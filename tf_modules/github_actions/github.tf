resource "github_repository_webhook" "aws_runners" {
  for_each   = toset(nonsensitive(var.github_repos))
  repository = each.key
  configuration {
    url          = module.runners.webhook.endpoint
    content_type = "json"
    insecure_ssl = false
    secret       = local.aws_github_runner_webhook_secret
  }

  active = true

  events = ["workflow_job"]
}