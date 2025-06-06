packer {
    required_plugins {
        amazon = {
            version = ">= 1.0.0"
            source = "github.com/hashicorp/amazon"
        }
    }
}

variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "ssh_private_key_file" {
  type = string
}

variable "ssh_keypair_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "kind" {
  type = string
}

variable "images" {}

locals {
  conf = {
    "arm64_al2023" : {
      installation_script_path = "${path.root}/../installation_scripts/basic_arm64_al2023.sh"
      base_ami_name_filter     = "al2023-ami-ecs-hvm-2023.0.20241031-kernel-6.1-arm64"
      instance_type            = "t4g.xlarge"
      github_link_arch         = "arm64"
    }
    "amd64_al2023" : {
      installation_script_path = "${path.root}/../installation_scripts/basic_amd64_al2023.sh"
      base_ami_name_filter     = "al2023-ami-ecs-hvm-2023.0.20241031-kernel-6.1-x86_64"
      instance_type            = "t3.xlarge"
      github_link_arch         = "x64"
    }
    "amd64_al2023_gpu" : {
      installation_script_path = "ami_generator/installation_scripts/basic_amd64_al2023.sh"
      base_ami_name_filter     = "Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.6.0 (Amazon Linux 2023) 20250323"
      instance_type            = "t3.xlarge"
      github_link_arch         = "x64"
    }
    "arm64_al2023_gpu" : {
      installation_script_path = "ami_generator/installation_scripts/basic_arm64_al2023.sh"
      base_ami_name_filter     = "Deep Learning ARM64 AMI OSS Nvidia Driver GPU PyTorch 2.6.0 (Amazon Linux 2023) 20250328"
      instance_type            = "t4g.xlarge"
      github_link_arch         = "arm64"
    }
  }

  runner_version   = "2.320.1"
  github_link_arch = local.conf[var.kind]["github_link_arch"]
}

source "amazon-ebs" "ami" {
    profile              = var.profile
    region               = var.region
    ssh_username         = "ec2-user"
    vpc_id               = var.vpc_id
    subnet_id            = var.subnet_id
    ssh_keypair_name     = var.ssh_keypair_name
    ssh_private_key_file = "${path.root}/../../${var.ssh_private_key_file}"
    temporary_security_group_source_public_ip = true
}


build {
  dynamic "source" {
    for_each = var.images
    labels = ["amazon-ebs.ami"]

    content {
      ami_name = source.value.ami_name

      instance_type = local.conf[var.kind]["instance_type"]

      source_ami_filter {
        filters = {
          name = local.conf[var.kind]["base_ami_name_filter"]
          root-device-type = "ebs"
          virtualization-type = "hvm"
        }

        most_recent = true
        owners = ["amazon"]
      }
      launch_block_device_mappings {
        device_name = "/dev/xvda"
        volume_size = source.value.volume_size
        volume_type = "gp3"
        delete_on_termination = true
      }
    }
  }

  provisioner "shell" {
    script = local.conf[var.kind]["installation_script_path"]
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }


  provisioner "shell" {
    environment_vars = [
      "RUNNER_TARBALL_URL=https://github.com/actions/runner/releases/download/v${local.runner_version}/actions-runner-linux-${local.github_link_arch}-${local.runner_version}.tar.gz"
    ]                                                                                                  

    script = "${path.root}/install-runner.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  provisioner "file" {
    content = templatefile("start-runner.sh", { metadata_tags = "enabled" })
    destination = "/tmp/start-runner.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/start-runner.sh /var/lib/cloud/scripts/per-boot/start-runner.sh",
      "sudo chmod +x /var/lib/cloud/scripts/per-boot/start-runner.sh",
    ]
  }
}

