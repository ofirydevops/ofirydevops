
locals {
    workflows_files_dir   = "${path.module}/workflows"
    workflows_files       = fileset(local.workflows_files_dir, "*")
    workflows_files_paths = { for file in local.workflows_files: file => "${local.workflows_files_dir}/${file}" }

    gh_actions_variables = {
        MAIN_AWS_REGION  = local.region
        MAIN_AWS_PROFILE = local.profile
        NAMESPACE        = local.namespace
    }

    gh_actions_secrets = {
        DEVOPS_PROJECT_TOKEN = local.secrets["devops_project_token"]
    }
}

resource "github_repository" "main" {
  name        = local.namespace
  description = "My awesome codebase"
  visibility  = "private" 
  auto_init   = true
}

data "github_repository" "main" {
  full_name = github_repository.main.full_name
}

resource "github_branch" "development" {
  repository = github_repository.main.name
  branch     = "update2"
}

resource "github_repository_file" "files" {
  for_each            = local.workflows_files_paths
  repository          = github_repository.main.name
  branch              = github_branch.development.branch
  file                = ".github/workflows/${each.key}"
  content             = file(each.value)
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = local.secrets["email"]
  overwrite_on_create = true
}

resource "github_repository_pull_request" "pr" {
    base_repository = github_repository.main.name
    base_ref        = data.github_repository.main.default_branch
    head_ref        = github_branch.development.branch
    title           = "My newest feature"
    body            = "This will change everything"
    depends_on      = [ github_repository_file.files ]
}

resource "github_actions_variable" "vars" {
    for_each      = local.gh_actions_variables
    repository    = github_repository.main.name
    variable_name = each.key
    value         = each.value
}

resource "github_actions_secret" "secrets" {
    for_each         = local.gh_actions_secrets
    repository       = github_repository.main.name
    secret_name      = each.key
    plaintext_value  = each.value
}