locals {
  global_conf = yamldecode(file("${path.module}/../../pylib/ofirydevops/global_conf.yaml"))
}
module "codeartifact" {
  source    = "../../tf_modules/codeartifact"
  profile   = local.global_conf["profile"]
  region    = local.global_conf["region"]
  namespace = local.global_conf["namespace"]
}

