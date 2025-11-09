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

variable "subnet_id" {
  type = string
}

variable "ebs_volume_id" {
  type = string
}

variable "keypair_name" {
  type = string
}

variable "local_workstation_pub_ip" {
  type = string
}

variable "keypair_privete_key" {
  type      = string
  sensitive = true
}

variable "jenkins_github_app_private_key_converted" {
  type      = string
  sensitive = true
}

variable "jenkins_github_app_id" {
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

variable "domain_ssl_info" {
  type = object({
    domain_ssl_cert       = string
    domain_ssl_chain      = string
    domain_ssl_privatekey = string
    domain                = string
  })
  default = null
}

variable "jenkins_admin_username" {
  type      = string
  sensitive = true
}


variable "jenkins_admin_password" {
  type      = string
  sensitive = true
}

variable "route53_domain_info" {
  type = object({
    route53_domain = string
    target_subdomain = string
  })
  default = null
}

variable "ami_ids" {
  type = object({
    basic_amd64_100GB = string
    basic_arm64_100GB = string
    gpu_amd64_100GB   = string
  })
}

variable "dsl_config" {
  type = any
}



