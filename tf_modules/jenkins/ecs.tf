locals {
    jenkins_casc_config_dir = "/var/jenkins_home/jcasc"
    ecr_repos = {
        jenkins = "${var.namespace}_jenkins"
    }
      
    
    jenkins_ecr_repo_url = aws_ecr_repository.ecr_repos["jenkins"].repository_url
    image_tag            = "hash_${substr(local.jenkins_image_dependency_hash, 0, 20)}"
    ecr_registry         = split("/", local.jenkins_ecr_repo_url)[0]
    ecr_repo_name        = split("/", local.jenkins_ecr_repo_url)[1]
    image_url            = "${local.ecr_registry}/${local.ecr_repo_name}:${local.image_tag}"


    arch            = "arm64"
    device_to_mount = "/dev/xvdh"
    arch_config = {
      "amd64" : {
        ami_regex = "amzn2-ami-ecs-hvm-2.0.20240730-x86_64-ebs"
        instance_type = "t3.medium"
      }
      "arm64" : {
        ami_regex = "amzn2-ami-ecs-hvm-2.0.20240730-arm64-ebs" 
        instance_type = "t4g.medium"
      }
    }

    domain_ssl_cert_files_conf = {
      "cert" : {
        path    = "tmp/cert.pem"
        content = var.domain_ssl_cert
      }
      "privatekey" : {
        path    = "tmp/privatekey.pem"
        content = var.domain_ssl_privatekey
      }
      "chain" : {
        path    = "tmp/chain.pem"
        content = var.domain_ssl_chain
      }
    }  


    docker_dep_files = [
      "${path.module}/docker/Dockerfile",
      "${path.module}/docker/setup_jenkins_ssl.sh",
      "${path.module}/docker/plugins.txt"
    ]

    docker_dep_files_content      = [for file in local.docker_dep_files : file(file)]
    docker_dep_files_content_hash = sha256(join("", local.docker_dep_files_content))
    ssl_data_hash                 = sha256(join("", [var.domain_ssl_privatekey, var.domain_ssl_cert, var.domain_ssl_chain]))
    jenkins_image_dependency_hash = sha256(join("", [local.docker_dep_files_content_hash, local.ssl_data_hash, local.arch]))
    casc_reload_token             = random_password.casc_reload_token.result

    ec2_assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }]
    })
    iam_roles = {
      "jenkins_master" : {
        name = "${var.namespace}_jenkins_master"
        assume_role_policy = local.ec2_assume_role_policy
        managed_policy_arns = [
          "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
        ]
        policy = jsonencode({
            Version = "2012-10-17"
            Statement = [
                {
                    Action = [
                        "ecr:*Get*",
                        "ecr:List*",
                        "ecr:Describe*",
                        "ecs:DescribeServices",
                        "ec2:CancelSpotInstanceRequests",
                        "ec2:GetConsoleOutput",
                        "ec2:RequestSpotInstances",
                        "ec2:RunInstances",
                        "ec2:StartInstances",
                        "ec2:StopInstances",
                        "ec2:TerminateInstances",
                        "ec2:CreateTags",
                        "ec2:DeleteTags",
                        "ec2:GetPasswordData",
                        "ec2:Describe*",
                        "ec2:*Spot*",
                        "ec2:ModifySpotFleetRequest",
                        "ec2:ModifyFleet",
                        "autoscaling:DescribeAutoScalingGroups",
                        "autoscaling:UpdateAutoScalingGroup",
                        "iam:ListInstanceProfiles",
                        "iam:ListRoles",
                        "iam:PassRole",
                        "iam:ListInstanceProfilesForRole",
                        "iam:CreateServiceLinkedRole"
                        ]
                    Effect   = "Allow"
                    Resource = "*"
                }
            ]
        })
      }

      "jenkins_worker" : {
        name = "${var.namespace}_jenkins_worker"
        assume_role_policy = local.ec2_assume_role_policy
        policy = jsonencode({
            Version = "2012-10-17"
            Statement = [
                {
                    Action = [
                        "ecr:*",
                        "ecs:*",
                        "ec2:*",
                        "autoscaling:*",
                        "iam:*",
                        "lambda:*",
                        "apigateway:*",
                        "sqs:*",
                        "cloudwatch:*",
                        "s3:*",
                        "ssm:*",
                        "logs:*",
                        "secretsmanager:*",
                        "events:*",
                        "batch:*",
                        "codeartifact:*",
                        "sts:*",
                        "route53:*",
                        "wafv2:*",
                        "acm:*"
                        ]
                    Effect   = "Allow"
                    Resource = "*"
                }
            ]
        })
      }
    }

    sgs = {
        jenkins_master = {
            name = "${var.namespace}_jenkins_master"

        }
        jenkins_worker = {
            name = "${var.namespace}_jenkins_worker"
        }
    }
}

resource "local_sensitive_file" "domain_cert_files" {
  for_each        = local.domain_ssl_cert_files_conf
  filename        = "${path.module}/../../${each.value.path}"
  file_permission = "0755"
  content         = each.value.content
}


resource "aws_ecr_repository" "ecr_repos" {
    for_each             = local.ecr_repos
    name                 = each.value
    image_tag_mutability = "MUTABLE"
    force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "ecr_repos" {
    for_each   = local.ecr_repos
    repository = aws_ecr_repository.ecr_repos[each.key].name
    policy     = file("${path.module}/policies/ecr_lifecycle_policy.json")
}

resource "null_resource" "docker_build_and_push_jenkins_image" {
  depends_on = [
    aws_ecr_repository.ecr_repos,
    local_sensitive_file.domain_cert_files
    ]
  triggers = {
    hash = local.jenkins_image_dependency_hash
  }
  provisioner "local-exec" {
    environment = {
      DOCKER_REGISTRY              = local.ecr_registry
      DOCKER_IMAGE_REPO            = local.ecr_repo_name
      DOCKER_IMAGE_TAG             = local.image_tag
      DOMAIN                       = var.domain
      REGION                       = var.region
      PROFILE                      = var.profile
      ARCH                         = local.arch
      BUILDX_BAKE_ENTITLEMENTS_FS  = "0"
      DOCKER_COMPOSE_PATH          = "${path.module}/docker/docker-compose.yml"
      DOMAIN_CERT_FILE             = local.domain_ssl_cert_files_conf["cert"].path
      DOMAIN_CERT_PRIVATE_KEY_FILE = local.domain_ssl_cert_files_conf["privatekey"].path
      DOMAIN_CERT_CHAIN_FILE       = local.domain_ssl_cert_files_conf["chain"].path
    }
    command = "${path.module}/build_and_push.sh"
  }
}


resource "random_password" "casc_reload_token" {
  length  = 32
  special = false
}

data "aws_ami" "ecs_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [local.arch_config[local.arch]["ami_regex"]]
  }

  filter {
    name   = "owner-id"
    values = ["591542846629"]
  }

  owners = ["591542846629"]
}

resource "aws_security_group" "sgs" {
  for_each = local.sgs
  name     = each.value.name
  vpc_id   = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "laptop_ssh_inbound" {
  for_each          = local.sgs
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${var.local_workstation_pub_ip}/32"]
  security_group_id = aws_security_group.sgs[each.key].id
}

resource "aws_security_group_rule" "master_to_worker_ssh_inbound" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = aws_security_group.sgs["jenkins_master"].id
  security_group_id = aws_security_group.sgs["jenkins_worker"].id
}

resource "aws_security_group_rule" "https_inbound" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["${var.local_workstation_pub_ip}/32"]
  security_group_id = aws_security_group.sgs["jenkins_master"].id
}

resource "aws_security_group_rule" "remote_dev_access" {
  type              = "ingress"
  from_port         = 5000
  to_port           = 5000
  protocol          = "tcp"
  cidr_blocks       = ["${var.local_workstation_pub_ip}/32"]
  security_group_id = aws_security_group.sgs["jenkins_worker"].id
}

resource "aws_iam_role" "roles" {
  for_each = local.iam_roles
  name = each.value.name
  managed_policy_arns = try(each.value.managed_policy_arns, null)
  assume_role_policy = each.value.assume_role_policy
  inline_policy {
    name = "inline_policy"
    policy = each.value.policy
  }
}

resource "aws_iam_instance_profile" "profiles" {
  for_each = local.iam_roles
  name = each.value.name
  role = aws_iam_role.roles[each.key].name
}

resource "aws_instance" "jenkins" {
  depends_on             = [ null_resource.docker_build_and_push_jenkins_image ]
  ami                    = data.aws_ami.ecs_ami.id
  instance_type          = local.arch_config[local.arch]["instance_type"]
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.sgs["jenkins_master"].id]
  iam_instance_profile   = aws_iam_instance_profile.profiles["jenkins_master"].name
  key_name               = var.keypair_name
  

  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.jenkins.name} >> /etc/ecs/ecs.config
  EOF
  tags = {
    Name = "${var.namespace}_jenkins"
  }
}

resource "aws_ecs_cluster" "jenkins" {
  name = "${var.namespace}_jenkins"
}
resource "aws_ecs_task_definition" "root_jenkins_task" {
  depends_on = [ null_resource.docker_build_and_push_jenkins_image ]
  family                   = "${var.namespace}_jenkins_ecs_task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "1800"
  memory                   = "3800"
  volume {
    name      = "jenkins_data_volume"
    host_path = "/var/jenkins_home"
  }
  container_definitions = jsonencode([
    {
      name      = "jenkins"
      image     = local.image_url
      essential = true
      environment = [
        { "name": "CASC_JENKINS_CONFIG", "value": "${local.jenkins_casc_config_dir}/" },
        { "name": "CASC_RELOAD_TOKEN",   "value": local.casc_reload_token             },
        
      ]
      mountPoints = [
        {
          "sourceVolume": "jenkins_data_volume",
          "containerPath": "/var/jenkins_home"
        }
      ]
      portMappings = [{
        containerPort = 8443
        hostPort      = 443
        protocol      = "tcp"
      }]
    }
  ])
}

resource "aws_ecs_service" "jenkins_service" {
  name            = "jenkins_ecs_service"
  cluster         = aws_ecs_cluster.jenkins.id
  task_definition = aws_ecs_task_definition.root_jenkins_task.arn
  desired_count   = 1
  launch_type     = "EC2"
  force_new_deployment = true
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
}

resource "aws_route53_record" "jenkins" {
  zone_id = var.domain_route53_hosted_zone_id
  name    = var.subdomain
  type    = "A"
  ttl     = 300
  records = [aws_instance.jenkins.public_ip]
}


resource "null_resource" "jenkins_ecs_setup" {
    depends_on = [aws_instance.jenkins]

    provisioner "remote-exec" {
      connection {
        type        = "ssh"
        host        = aws_instance.jenkins.public_ip
        user        = "ec2-user"
        private_key = var.keypair_privete_key
      }
      inline = [
        "sudo systemctl enable ecs",
        "sudo systemctl stop ecs",
        "sudo systemctl start ecs"
      ]
    }
}


resource "local_sensitive_file" "rendered_jcasc_config" {
  filename = "${path.module}/jcasc_config_tmp.yaml"
  file_permission = "0755"
  content  = templatefile("${path.module}/jcasc/main.tpl.yaml", {
    instance_profile                 = aws_iam_instance_profile.profiles["jenkins_worker"].arn
    sg_name                          = aws_security_group.sgs["jenkins_worker"].name
    subnet_id                        = var.subnet_id
    jenkins_admin_password           = var.jenkins_admin_password
    jenkins_admin_username           = var.jenkins_admin_username
    basic_100GB_amd64_ami_id         = var.ami_ids["basic_amd64_100GB"]
    basic_100GB_arm64_ami_id         = var.ami_ids["basic_arm64_100GB"]
    deep_learning_100GB_amd64_ami_id = var.ami_ids["gpu_amd64_100GB"]
    workers_ssh_key                  = indent(20, "\n${var.keypair_privete_key}")
    worker_role_arn                  = aws_iam_role.roles["jenkins_worker"].arn
    default_profile_name             = var.profile
    region                           = var.region
    namespace                        = var.namespace
    ecr_registry                     = local.ecr_registry
    github_token                     = var.github_token
    github_repo                      = var.github_repo
    gh_root_jenkins_app_id           = var.github_jenkins_app_id
    jenkins_gh_app_priv_key          = indent(20, "\n${var.github_jenkins_app_private_key_converted}")
  })
}


resource "aws_volume_attachment" "jenkins_attachment" {
  device_name = local.device_to_mount
  volume_id   = var.ebs_volume_id
  instance_id = aws_instance.jenkins.id
}

resource "null_resource" "jenkins_volume_mount" {
    triggers = {
      always_run = timestamp()
    }
    depends_on = [aws_volume_attachment.jenkins_attachment]
    provisioner "remote-exec" {
      connection {
        type        = "ssh"
        host        = aws_instance.jenkins.public_ip
        user        = "ec2-user"
        private_key = var.keypair_privete_key
      }
      inline = [
        "if ! sudo file -s \"$(readlink -f ${local.device_to_mount})\" | grep -q \"filesystem\"; then sudo mkfs.ext4 ${local.device_to_mount}; fi",
        "sudo mkdir -p /var/jenkins_home",
        "sudo mount ${local.device_to_mount} /var/jenkins_home",
        "sudo chown -R 1000:1000 /var/jenkins_home",
        "echo '${local.device_to_mount} /var/jenkins_home ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab"
      ]
    }
}


resource "null_resource" "jenkins_jcasc_update" {

    depends_on = [
      null_resource.jenkins_volume_mount,
      aws_ecs_service.jenkins_service
      ]
    triggers = {
      jcasc_config_file_hash = local_sensitive_file.rendered_jcasc_config.content_sha256
    }
    provisioner "file" {
        connection {
            type        = "ssh"
            host        = aws_instance.jenkins.public_ip
            user        = "ec2-user"
            private_key = var.keypair_privete_key
        }
        source      = local_sensitive_file.rendered_jcasc_config.filename
        destination = "${local.jenkins_casc_config_dir}/main.yaml"
    }
    provisioner "remote-exec" {
        connection {
            type        = "ssh"
            host        = aws_instance.jenkins.public_ip
            user        = "ec2-user"
            private_key = var.keypair_privete_key
        }
        inline = [
            "sudo chmod -R 600 ${local.jenkins_casc_config_dir}",
            "sudo chown -R 1000:1000 ${local.jenkins_casc_config_dir}",
            "curl -X POST --insecure https://127.0.0.1/reload-configuration-as-code/?casc-reload-token=${local.casc_reload_token} || true"
        ]
    }
}


module "jenkins_github_webhook" {
  source                    = "../../tf_modules/github_jenkins_webhook_gw"
  name                      = var.namespace
  domain                    = var.domain
  hosted_zone_id            = var.domain_route53_hosted_zone_id
  vpc_id                    = var.vpc_id
  github_repo               = var.github_repo
  jenkins_server_subnet_id  = var.subnet_id
  jenkins_server_private_ip = aws_instance.jenkins.private_ip
  jenkins_server_sg_id      = aws_security_group.sgs["jenkins_master"].id
}


resource "null_resource" "cleanup" {
  depends_on = [
    module.jenkins_github_webhook,
    null_resource.jenkins_jcasc_update
    ]
  triggers = {
    always = timestamp()
  }
  provisioner "local-exec" {
    command = "rm *.zip ${local_sensitive_file.rendered_jcasc_config.filename} || true"
  }
}