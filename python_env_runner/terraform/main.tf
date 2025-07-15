locals {

  global_conf = yamldecode(file("${path.module}/../../pylib/ofirydevops/global_conf.yaml"))

}

module "py_env_runner" {
  source    = "../../tf_modules/py_env_runner"
  profile   = local.global_conf["profile"]
  region    = local.global_conf["region"]
  namespace = local.global_conf["namespace"]
}

