variable "profile" {
  type = string
}

variable "region" {
  type = string
}

variable "namespace" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "keypair_name" {
  type = string
}

variable "gh_actions_runner_github_app_private_key" {
  type      = string
  sensitive = true
}

variable "gh_actions_runner_github_app_id" {
  type      = string
  sensitive = true
}

variable "github_repos" {
  type = list(string)
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "runner_configs_dir_abs_path" {
  type = string
}

variable "local_workstation_pub_ip" {
  type = string
}