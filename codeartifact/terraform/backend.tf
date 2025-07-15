terraform {
  backend "s3" {
    key = "codeartifact.tfstate"
  }

  required_providers {
    aws = "~> 5.0"
  }
}