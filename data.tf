data "aws_availability_zones" "available" {}


data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_caller_identity" "current" {}


# Wait 3 minutes for the fe and be resources to be created
resource "time_sleep" "wait_180_seconds" {
  depends_on = [resource.helm_release.starrocks_operator]

  create_duration = "180s"
}

# Get starrocks fe pod infomation
data "kubernetes_resources" "starrocks_fe_pods" {
  count          = var.fe_count
  api_version    = "v1"
  kind           = "Pod"
  namespace      = "starrocks"
  label_selector = "statefulset.kubernetes.io/pod-name=kube-starrocks-fe-${count.index}"

  depends_on = [time_sleep.wait_180_seconds]
}

