terraform {
  backend "s3" {
    key = "jenkins.tfstate"
  }

  required_providers {
    aws = "~> 5.0" 
  }
}