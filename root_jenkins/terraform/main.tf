terraform {
  backend "local" {
    path = "/home/terraform.tfstate"
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

locals {
    secrets = yamldecode(file("${path.module}/../secrets.yaml"))
}

provider "github" {
    token = local.secrets["github_token"]
}

resource "github_repository" "example" {
  name        = "example-test"
  description = "My awesome codebase"
  visibility  = "public"
  has_wiki    = true
  has_projects = true
  has_issues = true
  allow_squash_merge = false
  allow_rebase_merge = false
  delete_branch_on_merge = true
  allow_auto_merge = true
  auto_init = true
}

resource "github_branch" "test" {
  repository = github_repository.example.name
  branch     = "test"
}

resource "github_repository_file" "example" {
  repository          = github_repository.example.name
  branch              = github_branch.test.branch
  file                = ".gitignore"
  content             = "**/*.tfstate"
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}


resource "github_branch_protection" "example" {
  repository_id  = github_repository.example.name
  pattern        = "main"
  enforce_admins = true

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews = true
    require_code_owner_reviews = true
  }

  required_status_checks {
    strict = true
  }
}


resource "github_repository_webhook" "webhook" {
  repository = github_repository.example.name

  active = true

  configuration {
    url          = "https://adminjgw.tactilemobility.com/github_webhook"
    content_type = "json"
    insecure_ssl = false
    secret = "hello123"
  }

  events = ["issue_comment", "pull_request", "push"]
}