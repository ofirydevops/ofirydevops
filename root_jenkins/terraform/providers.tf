provider "aws" {
  profile = "OFIRYDEVOPS"
  region  = local.region
}

provider "github" {
  token = local.github_token
}