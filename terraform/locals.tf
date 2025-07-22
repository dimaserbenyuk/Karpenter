locals {
  cluster_name        = aws_eks_cluster.main.name
  karpenter_namespace  = "karpenter"
}