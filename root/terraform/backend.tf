terraform {
  backend "s3" {
    key = "pre-root-infra.tfstate"
  }

  required_providers {
    aws = "~> 5.0" 
  }
}

