provider "aws" {
  profile = "OFIRYDEVOPS"
  region  = local.region
}

provider "github" {
  token = local.ssm["/secrets/github_token"]
}