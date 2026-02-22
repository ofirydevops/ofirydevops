
data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  global_conf = yamldecode(file("${path.module}/../../pylib/ofirydevops/global_conf.yaml"))
  name   = "ex-eks-mng"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}


module "eks_al2023" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.name}-al2023"
  kubernetes_version = "1.33"

  # EKS Addons
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets



        # - `cluster_endpoint_private_access` -> `endpoint_private_access`
        # - `cluster_endpoint_public_access` -> `endpoint_public_access`
        # - `cluster_endpoint_public_access_cidrs` -> `endpoint_public_access_cidrs`

  # THIS IS THE IMPORTANT PART
    endpoint_public_access  = true   # ← enables the public endpoint
    endpoint_private_access = true   # ← optional, usually you keep this true

    # # Optional but recommended: restrict public access to only your IPs instead of the whole internet
    # endpoint_public_access_cidrs = [
    #   "1.2.3.4/32",           # your home / office IP
    #   "86.75.30.9/32",        # your other location, VPN exit, etc.
    #   # or temporarily while testing:
    #   # "0.0.0.0/0"
    # ]
  # Set authentication mode so the module uses access entries + config-map

  enable_cluster_creator_admin_permissions = true
  # authentication_mode = "API_AND_CONFIG_MAP"

  # # Define who can access the cluster
  # access_entries = {
  #   admin-user = {
  #     principal_arn = "arn:aws:iam::961341530050:user/admin"
  #     # optional policy associations (for example, restrict to certain IAM policies)
  #     policy_associations = {}
  #   }
  # }
  eks_managed_node_groups = {
    example = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      instance_types = ["t3.large"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size = 1
      max_size = 2
      # This value is ignored after the initial creation
      # https://github.com/bryantbiggs/eks-desired-size-hack
      desired_size = 1

      # This is not required - demonstrates how to pass additional configuration to nodeadm
      # Ref https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/api/
      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  shutdownGracePeriod: 30s
          EOT
        }
      ]
    }
  }

  tags = local.tags
}