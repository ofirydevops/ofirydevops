provider "aws" {
  profile = "OFIRYDEVOPS"
  region  = local.region
}

provider "github" {
  token = local.secrets["github_token"]
}