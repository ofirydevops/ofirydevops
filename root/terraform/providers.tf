provider "aws" {
  profile = local.profile
  region  = local.region
}

provider "github" {
  token = local.secrets["github_token"]
}
