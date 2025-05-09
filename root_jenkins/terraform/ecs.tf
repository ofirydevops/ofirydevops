data "aws_ssm_parameter" "params" {
  for_each = local.ssm_params_to_read
  name = each.value
  with_decryption = true
}
locals {

    jenkins_casc_config_dir = "/var/jenkins_home/jcasc"

    ssm_params_to_read = {
      "hosted_zone_id"                   : "hostedZoneId"
      "root_jenkins_key_pair"            : "rootJenkinsKeyPair"
      "basic_100GB_amd64_ami_id"         : "basic100GBAmd64AmiId"
      "basic_100GB_arm64_ami_id"         : "basic100GBArm64AmiId"
      "root_jenkins_volume_az"           : "rootJenkinsVolumeAz"
      "root_jenkins_volume_id"           : "rootJenkinsVolumeId"
      "deep_learning_100GB_amd64_ami_id" : "deepLearning100GBAmd64AmiId"
      "deep_learning_100GB_arm64_ami_id" : "deepLearning100GBArm64AmiId"
      "root_jenkins_private_key"         : "/secrets/rootJenkinsPrivateKey"
      "github_token"                     : "/secrets/github_token"
      "github_username"                  : "/secrets/github_username"
      "aws_access_key_id"                : "/secrets/aws_secret_access_key"
      "aws_secret_access_key"            : "/secrets/jenkins_admin_password"
      "jenkins_admin_password"           : "/secrets/jenkins_admin_password"
      "github_root_jenkins_app_priv_key" : "/secrets/githubRootJenkinsAppPrivateKey"
      "github_jenkins_webhook_secret"    : "/secrets/github_jenkins_webhook_secret"
      "github_root_jenkins_app_id"       : "/secrets/github_root_jenkins_app_id"
      "domain_ssl_cert_private_key"      : "/sslcerts/ofirydevops.com/privateKey"
      "domain_ssl_cert_chain"            : "/sslcerts/ofirydevops.com/chain"
      "domain_ssl_cert"                  : "/sslcerts/ofirydevops.com/cert"
    }

    ecr_repos = [
      "root_jenkins"
    ]

    hosted_zone_id                   = data.aws_ssm_parameter.params["hosted_zone_id"].value
    root_jenkins_key_pair            = data.aws_ssm_parameter.params["root_jenkins_key_pair"].value
    basic_100GB_amd64_ami_id         = data.aws_ssm_parameter.params["basic_100GB_amd64_ami_id"].value
    basic_100GB_arm64_ami_id         = data.aws_ssm_parameter.params["basic_100GB_arm64_ami_id"].value
    root_jenkins_volume_az           = data.aws_ssm_parameter.params["root_jenkins_volume_az"].value
    root_jenkins_volume_id           = data.aws_ssm_parameter.params["root_jenkins_volume_id"].value
    root_jenkins_subnet_id           = data.aws_subnet.jenkins_subnet.id
    deep_learning_100GB_arm64_ami_id = data.aws_ssm_parameter.params["deep_learning_100GB_arm64_ami_id"].value
    deep_learning_100GB_amd64_ami_id = data.aws_ssm_parameter.params["deep_learning_100GB_amd64_ami_id"].value
    root_jenkins_private_key         = data.aws_ssm_parameter.params["root_jenkins_private_key"].value
    github_token                     = data.aws_ssm_parameter.params["github_token"].value
    github_username                  = data.aws_ssm_parameter.params["github_username"].value
    aws_access_key_id                = data.aws_ssm_parameter.params["aws_access_key_id"].value
    aws_secret_access_key            = data.aws_ssm_parameter.params["aws_secret_access_key"].value
    jenkins_admin_password           = data.aws_ssm_parameter.params["jenkins_admin_password"].value
    github_jenkins_webhook_secret    = data.aws_ssm_parameter.params["github_jenkins_webhook_secret"].value
    domain_ssl_cert_private_key      = data.aws_ssm_parameter.params["domain_ssl_cert_private_key"].value
    domain_ssl_cert_chain            = data.aws_ssm_parameter.params["domain_ssl_cert_chain"].value
    domain_ssl_cert                  = data.aws_ssm_parameter.params["domain_ssl_cert"].value
    github_root_jenkins_app_priv_key = data.aws_ssm_parameter.params["github_root_jenkins_app_priv_key"].value
    github_root_jenkins_app_id       = data.aws_ssm_parameter.params["github_root_jenkins_app_id"].value

    root_jenkins_ecr_repo_url = aws_ecr_repository.ecr_repos["root_jenkins"].repository_url
    image_tag     = "hash_${substr(local.docker_dep_files_content_hash, 0, 20)}"
    ecr_registry  = split("/", local.root_jenkins_ecr_repo_url)[0]
    ecr_repo_name = split("/", local.root_jenkins_ecr_repo_url)[1]
    image_url     = "${local.ecr_registry}/${local.ecr_repo_name}:${local.image_tag}"

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
        path = "tmp/cert.pem"
        content = local.domain_ssl_cert
      }
      "privatekey" : {
        path = "tmp/privatekey.pem"
        content = local.domain_ssl_cert_private_key
      }
      "chain" : {
        path = "tmp/chain.pem"
        content = local.domain_ssl_cert_chain
      }
    }  

    arch = "arm64"
    device_to_mount = "/dev/xvdh"

    docker_dep_files = [
      "${path.module}/../docker/Dockerfile",
      "${path.module}/../docker/setup_jenkins_ssl.sh",
      "${path.module}/../docker/plugins.txt"
    ]

    docker_dep_files_content = [for file in local.docker_dep_files : file(file)]
    docker_dep_files_content_hash = sha256(join("", local.docker_dep_files_content))
}



resource "local_sensitive_file" "domain_cert_files" {
  for_each = local.domain_ssl_cert_files_conf
  filename = "${path.module}/../../${each.value.path}"
  file_permission = "0755"
  content  = each.value.content
}


data "aws_subnet" "jenkins_subnet" {
  availability_zone = local.root_jenkins_volume_az
  vpc_id = local.default_vpc_id
}

resource "aws_ecr_repository" "ecr_repos" {
    for_each = toset(local.ecr_repos)
    name     = each.key
    image_tag_mutability = "MUTABLE"
    force_delete = true
}

resource "aws_ecr_lifecycle_policy" "ecr_repos" {
    for_each = toset(local.ecr_repos)
    repository = aws_ecr_repository.ecr_repos[each.key].name
    policy = file("${path.module}/policies/ecr_lifecycle_policy.json")
}

resource "null_resource" "docker_build_and_push" {
  depends_on = [
    aws_ecr_repository.ecr_repos,
    local_sensitive_file.domain_cert_files
    ]
  triggers = {
    hash = local.docker_dep_files_content_hash
  }
  provisioner "local-exec" {
    environment = {
      DOCKER_REGISTRY       = local.ecr_registry
      DOCKER_IMAGE_REPO     = local.ecr_repo_name
      DOCKER_IMAGE_TAG      = local.image_tag
      DOMAIN                = local.domain
      REGION                = local.region
      PROFILE               = "OFIRYDEVOPS"
      MODULE_PATH           = path.module
      DOMAIN_CERT_FILE             = local.domain_ssl_cert_files_conf["cert"].path
      DOMAIN_CERT_PRIVATE_KEY_FILE = local.domain_ssl_cert_files_conf["privatekey"].path
      DOMAIN_CERT_CHAIN_FILE       = local.domain_ssl_cert_files_conf["chain"].path

    }
    command = "${path.module}/../docker/build_and_push.sh"
  }
}

locals {
  laptop_public_ip = trimspace(data.http.my_public_ip.response_body)


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
    "root_jenkins_master" : {
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

    "root_jenkins_worker" : {
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
                      "events:*"
                      ]
                  Effect   = "Allow"
                  Resource = "*"
              }
          ]
      })
    }
  }

  sgs = {
      "root_jenkins_master" : {

      }
      "root_jenkins_worker" : {
        
      }
  }
}

data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com"
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
  name        = each.key
  vpc_id      = local.default_vpc_id
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
  cidr_blocks       = ["${local.laptop_public_ip}/32"]
  security_group_id = aws_security_group.sgs[each.key].id
}

resource "aws_security_group_rule" "master_to_worker_ssh_inbound" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = aws_security_group.sgs["root_jenkins_master"].id
  security_group_id = aws_security_group.sgs["root_jenkins_worker"].id
}

resource "aws_security_group_rule" "https_inbound" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["${local.laptop_public_ip}/32"]
  security_group_id = aws_security_group.sgs["root_jenkins_master"].id
}

resource "aws_security_group_rule" "remote_dev_access" {
  type              = "ingress"
  from_port         = 5000
  to_port           = 5000
  protocol          = "tcp"
  cidr_blocks       = ["${local.laptop_public_ip}/32"]
  security_group_id = aws_security_group.sgs["root_jenkins_worker"].id
}

resource "aws_iam_role" "roles" {
  for_each = local.iam_roles
  name = each.key
  managed_policy_arns = try(each.value.managed_policy_arns, null)
  assume_role_policy = each.value.assume_role_policy
  inline_policy {
    name = "inline_policy"
    policy = each.value.policy
  }
}

resource "aws_iam_instance_profile" "profiles" {
  for_each = local.iam_roles
  name = each.key
  role = aws_iam_role.roles[each.key].name
}

resource "aws_instance" "root_jenkins" {
  depends_on = [ null_resource.docker_build_and_push ]
  ami           = data.aws_ami.ecs_ami.id
  instance_type = local.arch_config[local.arch]["instance_type"]
  subnet_id     = local.root_jenkins_subnet_id
  vpc_security_group_ids = [aws_security_group.sgs["root_jenkins_master"].id]
  iam_instance_profile = aws_iam_instance_profile.profiles["root_jenkins_master"].name
  key_name = local.root_jenkins_key_pair
  

  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.root_jenkins.name} >> /etc/ecs/ecs.config
  EOF
  tags = {
    Name = "root_jenkins"
  }
}

resource "aws_ecs_cluster" "root_jenkins" {
  name = "root_jenkins_cluster"
}
resource "aws_ecs_task_definition" "root_jenkins_task" {
  depends_on = [ null_resource.docker_build_and_push ]
  family                   = "jenkins_root_ecs_task"
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
      name      = "root_jenkins"
      image     = local.image_url
      essential = true
      environment = [
        { "name": "CASC_JENKINS_CONFIG", "value": "${local.jenkins_casc_config_dir}/" }
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

resource "aws_ecs_service" "root_jenkins_service" {
  name            = "root_jenkins_ecs_service"
  cluster         = aws_ecs_cluster.root_jenkins.id
  task_definition = aws_ecs_task_definition.root_jenkins_task.arn
  desired_count   = 1
  launch_type     = "EC2"
  force_new_deployment = true
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
}

resource "aws_route53_record" "root_jenkins" {
  zone_id = local.hosted_zone_id
  name    = "jenkins"
  type    = "A"
  ttl     = 300
  records = [aws_instance.root_jenkins.public_ip]
}


resource "null_resource" "root_jenkins_ecs_setup" {
    depends_on = [aws_instance.root_jenkins]

    provisioner "remote-exec" {
      connection {
        type        = "ssh"
        host        = aws_instance.root_jenkins.public_ip
        user        = "ec2-user"
        private_key = local.root_jenkins_private_key
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
  content  = templatefile("${path.module}/../jcasc/main.tpl.yaml", {
    instance_profile                 = aws_iam_instance_profile.profiles["root_jenkins_worker"].arn
    sg_name                          = aws_security_group.sgs["root_jenkins_worker"].name
    subnet_id                        = local.root_jenkins_subnet_id
    jenkins_admin_password           = local.jenkins_admin_password
    basic_100GB_amd64_ami_id         = local.basic_100GB_amd64_ami_id
    basic_100GB_arm64_ami_id         = local.basic_100GB_arm64_ami_id
    deep_learning_100GB_arm64_ami_id = local.deep_learning_100GB_arm64_ami_id
    deep_learning_100GB_amd64_ami_id = local.deep_learning_100GB_amd64_ami_id
    github_username                  = local.github_username
    github_token                     = local.github_token
    workers_ssh_key                  = indent(20, "\n${local.root_jenkins_private_key}")
    worker_role_arn                  = aws_iam_role.roles["root_jenkins_worker"].arn
    default_profile_name             = "OFIRYDEVOPS"
    region                           = local.region
    ecr_registry                     = local.ecr_registry
    gh_root_jenkins_app_id           = local.github_root_jenkins_app_id
    gh_root_jenkins_app_priv_key     = indent(20, "\n${local.github_root_jenkins_app_priv_key}")
  })
}


resource "aws_volume_attachment" "root_jenkins_attachment" {
  device_name = local.device_to_mount
  volume_id   = local.root_jenkins_volume_id
  instance_id = aws_instance.root_jenkins.id
}

resource "null_resource" "root_jenkins_volume_mount" {
    triggers = {
      always_run = timestamp()
    }
    depends_on = [aws_volume_attachment.root_jenkins_attachment]
    provisioner "remote-exec" {
      connection {
        type        = "ssh"
        host        = aws_instance.root_jenkins.public_ip
        user        = "ec2-user"
        private_key = local.root_jenkins_private_key
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


resource "null_resource" "root_jenkins_jcasc_update" {

    depends_on = [null_resource.root_jenkins_volume_mount]
    triggers = {
      jcasc_config_file_hash = local_sensitive_file.rendered_jcasc_config.content_sha256
    }
    provisioner "file" {
        connection {
            type        = "ssh"
            host        = aws_instance.root_jenkins.public_ip
            user        = "ec2-user"
            private_key = local.root_jenkins_private_key
        }
        source      = local_sensitive_file.rendered_jcasc_config.filename
        destination = "${local.jenkins_casc_config_dir}/main.yaml"
    }
    provisioner "remote-exec" {
        connection {
            type        = "ssh"
            host        = aws_instance.root_jenkins.public_ip
            user        = "ec2-user"
            private_key = local.root_jenkins_private_key
        }
        inline = [
            "sudo chmod -R 600 ${local.jenkins_casc_config_dir}",
            "sudo chown -R 1000:1000 ${local.jenkins_casc_config_dir}"
        ]
    }
}


module "jenkins_github_webhook" {
  source                        = "../../tf_modules/github_jenkins_webhook_gw"
  name                          = "ofiry"
  domain                        = local.domain
  hosted_zone_id                = local.hosted_zone_id
  github_jenkins_webhook_secret = local.github_jenkins_webhook_secret
  vpc_id                        = local.default_vpc_id
  git_repo                      = local.global_conf["git_repo"]
  jenkins_server_subnet_id      = local.root_jenkins_subnet_id
  jenkins_server_private_ip     = aws_instance.root_jenkins.private_ip
  jenkins_server_sg_id          = aws_security_group.sgs["root_jenkins_master"].id
}



resource "null_resource" "cleanup" {
  depends_on = [
    module.jenkins_github_webhook,
    null_resource.root_jenkins_jcasc_update
    ]
  triggers = {
    always = timestamp()
  }
  provisioner "local-exec" {
    command = "rm *.zip ${local_sensitive_file.rendered_jcasc_config.filename} || true"
  }
}