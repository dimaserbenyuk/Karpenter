terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.97.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "~> 2.13.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}


provider "aws" {
  shared_config_files      = ["/Users/dmytroserbeniuk/.aws/config"]
  shared_credentials_files = ["/Users/dmytroserbeniuk/.aws/credentials"]
  profile                  = "default"
  region                   = "eu-central-1"
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--region", "eu-central-1",
      "--cluster-name", aws_eks_cluster.main.name
    ]
  }
}
