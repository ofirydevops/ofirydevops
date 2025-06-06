terraform {
  backend "s3" {
    key = "root-infra.tfstate"
  }

  required_providers {
    aws = "~> 5.0" 
  }
}