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

variable "basic_amd64_100GB_ami_id" {
  type = string
}

variable "basic_arm64_100GB_ami_id" {
  type = string
}

variable "gpu_amd64_100GB_ami_id" {
  type = string
}

variable "local_workstation_pub_ip" {
  type = string
}