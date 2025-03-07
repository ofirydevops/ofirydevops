terraform {
  backend "s3" {
    bucket  = "ofirydevops-root-terraform-state"
    key     = "root-infra.tfstate"
    region  = "eu-central-1"
    encrypt = "true"
    profile = "OFIRYDEVOPS"
  }

  required_providers {
    aws = "~> 5.0" 
  }
}