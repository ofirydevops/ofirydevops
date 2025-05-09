terraform {
  backend "s3" {
    bucket  = "ofirydevops-root-terraform-state"
    key     = "batch-runner.tfstate"
    region  = "eu-central-1"
    encrypt = "true"
    profile = "OFIRYDEVOPS"
  }

  required_providers {
    aws = "~> 5.0" 
  }
}