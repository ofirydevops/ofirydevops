variable "name" {
  type = string
}

variable "route53_domain" {
  type    = string
  default = null
}

variable "vpc_id" {
  type = string
}

variable "github_repos" {
  type = list(string)
}

variable "jenkins_server_subnet_id" {
  type = string
}

variable "jenkins_server_url_for_webhook_lambda" {
  type = string
}

variable "jenkins_server_sg_id" {
  type = string
}
