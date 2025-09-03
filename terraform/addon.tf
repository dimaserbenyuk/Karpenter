resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = "v1.11.4-eksbuild.14" #e.g., previous version v1.9.3-eksbuild.3 and the new version is v1.10.1-eksbuild.1
  resolve_conflicts_on_update = "PRESERVE"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.19.6-eksbuild.7"
  resolve_conflicts_on_update = "PRESERVE"

  service_account_role_arn = aws_iam_role.example.arn

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.example,
    aws_eks_addon.coredns
  ]
}


data "aws_iam_policy_document" "example_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_oidc.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "example" {
  assume_role_policy = data.aws_iam_policy_document.example_assume_role_policy.json
  name               = "example-vpc-cni-role"
}

resource "aws_iam_role_policy_attachment" "example" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.example.name
}

# EBS CSI Driver as EKS Add-on (migration from Helm)
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = "v1.35.0-eksbuild.1" # актуальная версия
  resolve_conflicts_on_update = "OVERWRITE"  # Принудительно заменяет ресурсы

  service_account_role_arn = aws_iam_role.ebs_csi_role.arn

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.ebs_csi_role,
  ]
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ebs_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "ebs_csi_role" {
  name = "AmazonEKS_EBS_CSI_DriverRole"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc.arn]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = "v1.1.0-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_cluster.main]
}

# EFS CSI Driver IAM Role
resource "aws_iam_role" "efs_csi_role" {
  name = "AmazonEKS_EFS_CSI_DriverRole"

  assume_role_policy = data.aws_iam_policy_document.efs_csi_assume_role.json
}

data "aws_iam_policy_document" "efs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc.arn]
    }
  }
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_policy" {
  role       = aws_iam_role.efs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# EFS CSI Driver as EKS Add-on (for future migration from Helm)
# Commented out until ready to migrate
resource "aws_eks_addon" "efs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-efs-csi-driver"
  addon_version               = "v2.1.11-eksbuild.1" # Check latest version
  resolve_conflicts_on_update = "OVERWRITE"

  service_account_role_arn = aws_iam_role.efs_csi_role.arn

  configuration_values = jsonencode({
    controller = {
      # We need this to run on Fargate, so remove node selector and use non-privileged mode
      containerSecurityContext = {
        privileged = false  
      },
      # No nodeSelector to allow scheduling on Fargate
      resources = {
        requests = {
          cpu = "100m",
          memory = "128Mi"
        },
        limits = {
          cpu = "100m",
          memory = "128Mi"
        }
      },
      # Add tolerations to ensure it can run on various node types
      tolerations = [
        {
          operator = "Exists"
        }
      ]
    },
    node = {
      # Only use supported parameters
      tolerations = [
        {
          operator = "Exists"
        }
      ],
      # Target ARM nodes specifically for your test case
      nodeSelector = {
        "karpenter.sh/nodepool" = "arm-pool"  # Target the same nodes as your test pod
      }
    }
  })

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.efs_csi_role,
  ]
}

# StorageClass for EBS CSI Driver (recreated after Helm migration)
resource "kubernetes_storage_class" "ebs_sc" {
  provider = kubernetes.eks
  
  metadata {
    name = "ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
    labels = {
      "my-label-is" = "supercool"
    }
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

# StorageClass for EFS CSI Driver
resource "kubernetes_storage_class" "efs_sc" {
  provider = kubernetes.eks
  
  metadata {
    name = "efs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }
  
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"
  
  parameters = {
    provisioningMode     = "efs-ap"
    fileSystemId         = "fs-013a88667c7393340"
    directoryPerms       = "700"
    gidRangeStart        = "1000"
    gidRangeEnd          = "2000"
    ensureUniqueDirectory = "true"
  }

  mount_options = ["tls"]

  depends_on = [aws_eks_addon.efs_csi]
}
