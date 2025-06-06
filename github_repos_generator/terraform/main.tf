
locals {
    global_conf = jsondecode(file("${path.module}/../../global_conf.json"))
    secrets     = yamldecode(file("${path.module}/../../secrets.yaml"))
    
    workflows_files_dir = "${path.module}/workflows"
    workflows_files = fileset(local.workflows_files_dir, "*")

    workflows_files_paths = { for file in local.workflows_files: file => "${local.workflows_files_dir}/${file}" }

}

resource "github_repository" "main" {
  name        = local.secrets["github_repo_v2"]
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
  commit_email        = local.global_conf["email"]
  overwrite_on_create = true
}

resource "github_repository_pull_request" "pr" {
    base_repository = github_repository.main.name
    base_ref        = data.github_repository.main.default_branch
    head_ref        = github_branch.development.branch
    title           = "My newest feature"
    body            = "This will change everything"
    depends_on = [ github_repository_file.files ]
}