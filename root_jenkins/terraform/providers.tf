provider "aws" {
  profile = local.profile
  region  = local.region
}

provider "github" {
  token = local.ssm["/secrets/github_token"]
}