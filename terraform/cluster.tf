resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"
  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private1.id,
      aws_subnet.private2.id
    ]
  }
}


resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "fp-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate_pod_exec_role.arn
  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]

  selector {
    namespace = "kube-system"
  }

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_fargate_profile" "karpenter" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "fp-karpenter"
  pod_execution_role_arn = aws_iam_role.fargate_pod_exec_role.arn
  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]

  selector {
    namespace = "karpenter"
  }

  depends_on = [aws_eks_cluster.main]
}

data "aws_eks_cluster" "main" {
  name = aws_eks_cluster.main.name
}

data "aws_caller_identity" "current" {}


resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url             = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["c3c07e30211ff224dc6db2086d7bbaa42929a81e"]
}

resource "aws_iam_role" "karpenter_controller" {
  name = "KarpenterControllerRole-${local.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${local.karpenter_namespace}:karpenter"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "karpenter_controller_inline" {
  name = "KarpenterControllerPolicy-${local.cluster_name}"
  role = aws_iam_role.karpenter_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "Karpenter"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Sid = "ConditionalEC2Termination"
        Effect = "Allow"
        Action = "ec2:TerminateInstances"
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid = "PassNodeRoles"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterNodeRole-${local.cluster_name}",
          aws_iam_role.karpenter_node.arn
        ]
      },
      {
        Sid = "EKSClusterEndpointLookup"
        Effect = "Allow"
        Action = "eks:DescribeCluster"
        Resource = "arn:aws:eks:eu-central-1:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}"
      },
      {
        Sid = "AllowInstanceProfileReadActions"
        Effect = "Allow"
        Action = "iam:GetInstanceProfile"
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "karpenter" {
  name        = "eks-cluster-sg-eks-cluster"
  description = "EKS created security group applied to ENI that is attached to EKS Control Plane master nodes, as well as any managed workloads."
  vpc_id      = aws_vpc.main.id

  tags = {
    "karpenter.sh/discovery" = "eks-cluster"
    "Name"                   = "eks-cluster-sg-eks-cluster"
  }
}

# Self-reference rule (allow all internal communication)
resource "aws_security_group_rule" "karpenter_ingress_all_from_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # All
  security_group_id = aws_security_group.karpenter.id
  source_security_group_id = aws_security_group.karpenter.id
}

resource "aws_security_group_rule" "karpenter_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.karpenter.id
}
