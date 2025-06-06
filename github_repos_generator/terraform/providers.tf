provider "aws" {
  profile = local.global_conf["profile"]
  region  = local.global_conf["region"]
}

provider "github" {
  token = local.secrets["github_token_v2"]
}