variable "name" {
    type = string
}

variable "domain" {
    type = string
}

variable "hosted_zone_id" {
    type = string
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

variable "jenkins_server_private_ip" {
    type = string
}

variable "jenkins_server_sg_id" {
    type = string
}
