packer {
    required_plugins {
        amazon = {
            version = ">= 1.0.0"
            source = "github.com/hashicorp/amazon"
        }
    }
}

variable "kind" {
  type = string
  default = "amd64"
}

variable "images" {}


locals {
  conf = {
    "arm64_al2023" : {
      installation_script_path = "ami_generator/installation_scripts/basic_arm64_al2023.sh"
      base_ami_name_filter = "al2023-ami-ecs-hvm-2023.0.20241031-kernel-6.1-arm64"
      instance_type = "t4g.xlarge"
    }
    "amd64_al2023" : {
      installation_script_path = "ami_generator/installation_scripts/basic_amd64_al2023.sh"
      base_ami_name_filter = "al2023-ami-ecs-hvm-2023.0.20241031-kernel-6.1-x86_64"
      instance_type = "t3.xlarge"
    }
    "amd64_al2023_gpu" : {
      installation_script_path = "ami_generator/installation_scripts/basic_amd64_al2023.sh"
      base_ami_name_filter = "Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.6.0 (Amazon Linux 2023) 20250323"
      instance_type = "t3.xlarge"
    }
    "arm64_al2023_gpu" : {
      installation_script_path = "ami_generator/installation_scripts/basic_arm64_al2023.sh"
      base_ami_name_filter = "Deep Learning ARM64 AMI OSS Nvidia Driver GPU PyTorch 2.6.0 (Amazon Linux 2023) 20250328"
      instance_type = "t4g.xlarge"
    }
    "amd64_amzn2_gpu" : {
      installation_script_path = "ami_generator/installation_scripts/basic_amd64.sh"
      base_ami_name_filter = "amzn2-ami-ecs-gpu-hvm-2.0.20250121-x86_64-ebs"
      instance_type = "t3.xlarge"
    }
  }


  global_conf = jsondecode(file("${path.root}/../../global_conf.json"))

  default_vpc_id = local.global_conf["default_vpc_id"]
  default_public_subnets = local.global_conf["default_public_subnets"]
}

source "amazon-ebs" "ami" {
    profile = "OFIRYDEVOPS"
    region = local.global_conf["region"]
    ssh_username = "ec2-user"
    vpc_id = local.default_vpc_id
    subnet_id = local.default_public_subnets[0]
    ssh_keypair_name = "root_jenkins"
    ssh_private_key_file = "root/key_pair/root_jenkins.secret.key"
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
}

