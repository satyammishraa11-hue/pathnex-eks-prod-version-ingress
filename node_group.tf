data "aws_iam_role" "eks_node" {
  name = "AmazonEKSNodeRole"
}

resource "aws_eks_node_group" "pathnex-NG" {
  cluster_name    = aws_eks_cluster.pathnex.name
  node_group_name = "pathnex-ng"

  node_role_arn = data.aws_iam_role.eks_node.arn

  subnet_ids = var.private_subnet_ids

  version        = "1.36"
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "SPOT"
  instance_types = ["c7i-flex.large"]
  disk_size      = 20

  scaling_config {
    desired_size = 3
    min_size     = 1
    max_size     = 4
  }

  tags = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }



  update_config {
    max_unavailable = 1
    update_strategy = "DEFAULT"
  }

}

resource "aws_autoscaling_group_tag" "cluster_autoscaler" {
  for_each = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  }

  autoscaling_group_name = aws_eks_node_group.pathnex-NG.resources[0].autoscaling_groups[0].name

  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = false
  }
}
