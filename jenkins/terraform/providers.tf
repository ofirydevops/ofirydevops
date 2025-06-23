provider "aws" {
  profile = local.profile
  region  = local.region
}

provider "random" {}