provider "aws" {
  profile = local.global_conf["profile"]
  region  = local.global_conf["region"]
}