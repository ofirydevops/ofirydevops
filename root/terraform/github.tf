
locals {
    workflows_files_dir   = "${path.module}/workflows"
    workflows_files       = fileset(local.workflows_files_dir, "*")
    workflows_files_paths = { 
      for file in local.workflows_files: file => {
        content = file("${local.workflows_files_dir}/${file}")
        dst     = ".github/workflows/${file}"
      } 
    }

    workflows_tpl_files_dir   = "${path.module}/workflows_templates"
    workflows_tpl_files       = fileset(local.workflows_tpl_files_dir, "*")
    workflows_tpl_files_paths = { 
      for file in local.workflows_tpl_files: file => {
        content = templatefile("${local.workflows_tpl_files_dir}/${file}", { 
          repositories        = jsonencode(local.all_repos)
          default_repository  = github_repository.main.full_name
          default_py_env_file = "python_env_runner/examples/envs/ofiry.yaml"
          default_enterypoint = "python python_env_runner/examples/tests/hello_world.py"
        })
        dst     = ".github/workflows/${file}"
      }
    }


    jenkinsfiles_dir   = "${path.module}/jenkinsfiles"
    jenkinsfiles       = fileset(local.jenkinsfiles_dir, "*")
    jenkinsfiles_paths = {
      for file in local.jenkinsfiles: file => {
        content = file("${local.jenkinsfiles_dir}/${file}")
        dst     = "jenkinsfiles/${file}"
      }
    }

    python_env_files_dir   = "${path.module}/../../python_env_runner/examples"
    python_env_files       = fileset(local.python_env_files_dir, "**")
    python_env_files_paths = { 
      for file in local.python_env_files: file => {
        content = file("${local.python_env_files_dir}/${file}")
        dst     = "python_env_runner/examples/${file}"
      }
    }




    all_files_paths = merge(local.workflows_files_paths, 
                            local.jenkinsfiles_paths, 
                            local.workflows_tpl_files_paths, 
                            local.python_env_files_paths)

    all_repos = data.github_repositories.all_accessible.full_names


    gh_actions_variables = {
      MAIN_AWS_REGION  = local.region
      MAIN_AWS_PROFILE = local.profile
      NAMESPACE        = local.namespace
    }

    gh_actions_secrets = {
      OFIRYDEVOPS_GITHUB_TOKEN = local.secrets["github_token"]
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
  for_each            = local.all_files_paths
  repository          = github_repository.main.name
  branch              = github_branch.development.branch
  file                = each.value.dst
  content             = each.value.content
  commit_message      = "Created by ofirydevops project"
  overwrite_on_create = true
}

resource "github_repository_pull_request" "pr" {
    base_repository = github_repository.main.name
    base_ref        = data.github_repository.main.default_branch
    head_ref        = github_branch.development.branch
    title           = "Example PR"
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

data "github_user" "self" {
  username = ""
}
data "github_repositories" "all_accessible" {
  query           = "user:${data.github_user.self.login} archived:false"
  include_repo_id = true
}
