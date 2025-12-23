module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    # Cost optimized node group - uses spot instances
    cost_optimized = {
      name            = "cost-optimized"
      use_name_prefix = false

      subnet_ids = module.vpc.private_subnets

      min_size     = 2
      max_size     = 5
      desired_size = 2

      ami_type       = "AL2_x86_64"
      capacity_type  = var.use_spot_instances ? "SPOT" : "ON_DEMAND"
      instance_types = var.node_instance_types

      # Node labels for observability stack
      labels = {
        node-type      = "cost-optimized"
        observability  = "enabled"
      }

      # Taints for better pod placement
      taints = {
        dedicated = {
          key    = "cost-optimized"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Enable detailed monitoring
      enable_monitoring = true

      # Node IAM role
      iam_role_additional_policies = {
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Update configuration
      update_config = {
        max_unavailable_percentage = 33
      }

      tags = {
        CostCenter    = "platform"
        SpotInstance  = var.use_spot_instances ? "true" : "false"
        AutoScaler    = "enabled"
      }
    }

    # System node group for critical components
    system = {
      name            = "system"
      use_name_prefix = false

      subnet_ids = module.vpc.private_subnets

      min_size     = 1
      max_size     = 3
      desired_size = 1

      ami_type       = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"
      instance_types = ["t3.medium"]

      labels = {
        node-type      = "system"
        critical       = "true"
      }

      taints = {
        dedicated = {
          key    = "system"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # Prefer to schedule system pods here
      kubelet_extra_args = "--register-with-taints=system=true:NoSchedule"

      tags = {
        CostCenter = "platform"
        NodeType   = "system"
      }
    }
  }

  # Cluster security group
  cluster_security_group_additional_rules = {
    ingress_nodes_https = {
      description                   = "Nodes to cluster API"
      protocol                      = "tcp"
      from_port                     = 443
      to_port                       = 443
      type                          = "ingress"
      source_node_security_group = true
    }
    ingress_allow_access_from_office = {
      description                   = "Office IP for kubectl access"
      protocol                      = "tcp"
      from_port                     = 443
      to_port                       = 443
      type                          = "ingress"
      cidr_blocks                   = var.office_ip_cidrs
    }
  }

  # Enable important EKS features
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # IRSA for service accounts
  enable_irsa = true

  # KMS key for cluster encryption
  create_kms_key = true
  kms_key_enable_default_policy = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  tags = {
    Environment = var.environment
    Project     = "eks-observability-demo"
  }
}

# Cluster Autoscaler IAM policy
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.cluster_name}-cluster-autoscaler"
  description = "Policy for Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to node IAM role
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = module.eks.eks_managed_node_groups["cost_optimized"].iam_role_name
}

# External DNS IAM policy (if using Route53)
resource "aws_iam_policy" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name        = "${var.cluster_name}-external-dns"
  description = "Policy for External DNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = ["*"]
      }
    ]
  })
}