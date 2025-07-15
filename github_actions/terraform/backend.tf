terraform {
  backend "s3" {
    key = "github-aws-runner.tfstate"
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }

    aws = "~> 5.0"
  }
}