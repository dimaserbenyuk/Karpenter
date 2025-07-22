# resource "helm_release" "karpenter" {
#   name             = "karpenter"
#   namespace        = "karpenter"
#   create_namespace = true
#   chart            = "karpenter"
#   repository       = "oci://public.ecr.aws/karpenter"
#   version          = "1.5.1"

#   set {
#     name  = "settings.aws.clusterName"
#     value = "eks-cluster"
#   }

#   set {
#     name  = "settings.aws.clusterEndpoint"
#     value = data.aws_eks_cluster.main.endpoint
#   }

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = aws_iam_role.karpenter_controller.arn
#   }

#   provider = helm.eks
# }
