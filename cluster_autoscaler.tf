
resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  namespace        = "kube-system"
  create_namespace = false

  chart = "${path.module}/charts/cluster-autoscaler-9.60.0.tgz"

  values = [
    yamlencode({
      autoDiscovery = {
        clusterName = aws_eks_cluster.pathnex.name
      }

      awsRegion     = var.aws_region
      cloudProvider = "aws"

      rbac = {
        serviceAccount = {
          create = true
          name   = "cluster-autoscaler"
        }
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.pathnex-NG,
    aws_autoscaling_group_tag.cluster_autoscaler,
    aws_eks_pod_identity_association.cluster_autoscaler
  ]
}
