terraform {
  backend "s3" {
    key = "batch-runner.tfstate"
  }

  required_providers {
    aws = "~> 5.0" 
  }
}