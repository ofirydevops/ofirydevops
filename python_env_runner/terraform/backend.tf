terraform {
  backend "s3" {
    key = "python-env-runner.tfstate"
  }

  required_providers {
    aws = "~> 5.0" 
  }
}