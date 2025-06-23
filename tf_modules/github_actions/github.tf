resource "github_repository_webhook" "aws_runners" {
  repository = local.github_repo
  configuration {
    url          = module.runners.webhook.endpoint
    content_type = "json"
    insecure_ssl = false
    secret       = local.aws_github_runner_webhook_secret
  }

  active = true

  events = ["workflow_job"]
}

resource "github_actions_variable" "vars" {
  for_each      = local.gh_actions_variables
  repository    = local.github_repo
  variable_name = each.key
  value         = each.value
}
