resource "aws_eks_access_entry" "root_access" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::272509770066:root"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "root_admin_group" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::272509770066:root"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX" # OK
}
