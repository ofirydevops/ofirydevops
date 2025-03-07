terraform {
  backend "s3" {
    bucket  = "ofirydevops-root-terraform-state"
    key     = "github-aws-runner.tfstate"
    region  = "eu-central-1"
    encrypt = "true"
    profile = "OFIRYDEVOPS"
  }

  required_providers {
      github = {
        source  = "integrations/github"
        version = "~> 5.0"
      }
    
    aws = "~> 5.0" 
  }
}