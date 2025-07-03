
locals {

    all_tf_projects              = keys(yamldecode(file("${path.module}/../../deployment/tf_projects.yaml")))
    ami_confs                    = keys(yamldecode(file("${path.module}/../../ami_generator/main_conf.yaml")))    
    gh_runners_conf_dir          = "${path.module}/../../github_actions/terraform/runner_configs"
    github_runners_conf_files    = [ for file in fileset(local.gh_runners_conf_dir, "*"): "${local.gh_runners_conf_dir}/${file}" ]
    github_runners_conf_combined = merge([for conf_file in local.github_runners_conf_files: yamldecode(file(conf_file))]...)
    github_runner_labels         = keys(local.github_runners_conf_combined)
    all_github_repos             = data.github_repositories.all_accessible.full_names
    generated_repo_full_name     = github_repository.main.full_name
    ofirydevops_ref              = "update2"
    tf_actions                   = ["plan", "apply", "destroy", "validate"]

    all_tf_projects_except_root = [
      for tf_project in local.all_tf_projects : tf_project if tf_project != "root"
    ]

    jenkins_dsl_config_json = jsonencode({
      ami_confs                        = local.ami_confs
      tf_projects                      = local.all_tf_projects_except_root
      tf_actions                       = local.tf_actions
      ofirydevops_ref                  = local.ofirydevops_ref
      generated_gh_repo_url            = github_repository.main.http_clone_url
      generated_gh_repo_name           = github_repository.main.name
      generated_gh_repo_pr_jenkinsfile = local.jenkinsfiles_paths["example_pr.groovy"]["dst"]
    })

    workflows_files_dir   = "${path.module}/workflows"
    workflows_files       = fileset(local.workflows_files_dir, "**")
    workflows_files_paths = { 
      for file in local.workflows_files: file => {
        content = templatefile("${local.workflows_files_dir}/${file}", { 
          repositories         = jsonencode(local.all_github_repos)
          default_repository   = local.generated_repo_full_name
          default_py_env_file  = "python_env_runner/examples/envs/py310_full.yaml"
          default_enterypoint  = "python python_env_runner/examples/tests/test_all_imports.py"
          ami_confs            = jsonencode(local.ami_confs)
          tf_projects          = jsonencode(local.all_tf_projects_except_root)
          github_runner_labels = jsonencode(local.github_runner_labels)
          ofirydevops_ref      = local.ofirydevops_ref
          tf_actions           = jsonencode(local.tf_actions)
        })
        dst = ".github/workflows/${file}"
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
                            local.python_env_files_paths)



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
  query           = "user:${data.github_user.self.login} archived:false sort:updated-asc"
  include_repo_id = true
  depends_on      = [ github_repository.main ]
}
