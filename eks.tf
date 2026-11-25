
data "aws_iam_role" "eks_cluster" {
  name = "AmazonEKSClusterRole"
}

resource "aws_eks_cluster" "pathnex" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.eks_cluster.arn
  version  = "1.36"

  # Allow EKS access entries and aws-auth authentication
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  vpc_config {
    subnet_ids = var.private_subnet_ids

    endpoint_public_access  = true
    endpoint_private_access = true

    public_access_cidrs = var.api_public_access_cidrs
  }

  zonal_shift_config {
    enabled = false
  }
}
