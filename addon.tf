#---------------------------------------------------------------
# GP3 Encrypted Storage Class
#---------------------------------------------------------------
resource "kubernetes_annotations" "gp2_default" {
  annotations = {
    "storageclass.kubernetes.io/is-default-class" : "false"
  }
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  force = true

  depends_on = [module.eks]
}

resource "kubernetes_storage_class" "ebs_csi_encrypted_gp3_storage_class" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    fsType    = "xfs"
    encrypted = true
    type      = "gp3"
  }

  depends_on = [kubernetes_annotations.gp2_default]
}

#---------------------------------------------------------------
# IRSA for EBS CSI Driver
#---------------------------------------------------------------
module "ebs_csi_driver_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "~> 5.14"
  role_name             = format("%s-%s", var.name, "ebs-csi-driver")
  attach_ebs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

#---------------------------------------------------------------
# Add-ons
#---------------------------------------------------------------
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  #---------------------------------------------------------------
  # Amazon EKS Managed Add-ons
  #---------------------------------------------------------------
  
  eks_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  depends_on = [module.eks]

  #---------------------------------------
  # Metrics Server
  #---------------------------------------
  enable_metrics_server = true
  metrics_server = {
    values = [templatefile("${path.module}/helm-values/metrics-server-values.yaml", {})]
  }

  #---------------------------------------
  # Karpenter Autoscaler for EKS Cluster
  #---------------------------------------
  enable_karpenter                  = true
  karpenter_enable_spot_termination = true
  karpenter_node = {
    iam_role_use_name_prefix     = false
    iam_role_name                = "${var.name}-karpenter-node"
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  karpenter = {
    chart_version       = "v0.34.0"
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }

  #---------------------------------------
  # Prommetheus and Grafana stack
  #---------------------------------------
  enable_kube_prometheus_stack = true
  kube_prometheus_stack = {
    namespace     = "monitoring"
    set_sensitive = [
      {
        name  = "grafana.adminPassword"
        value = var.grafana_password
        }]
    
    values = [
      templatefile("${path.module}/monitoring/kube-prometheus.yaml", {
        fe_targets = local.starrocks_fe_targets
        })
      ]
    }
  }

resource "kubernetes_config_map" "starrocks-dashboard" {
  metadata {
    name = "starrocks-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "starrocks-dashboard-starlet.json" = "${file("${path.module}/monitoring/starrocks-grafana-dashboard-starlet.json")}",
    "starrocks-dashboard-general.json" = "${file("${path.module}/monitoring/starrocks-grafana-dashboard-general.json")}"
  }

  depends_on = [
    module.eks_blueprints_addons.kube_prometheus_stack
  ]

}

#---------------------------------------
# Karpenter Provisioners
#---------------------------------------
# data "kubectl_path_documents" "karpenter_resources" {
#   pattern = "${path.module}/karpenter-resources/node-*.yaml"
#   vars = {
#     azs            = local.region
#     eks_cluster_id = module.eks.cluster_name
#   }
# }

# resource "kubectl_manifest" "karpenter_resources" {
#   for_each  = toset(data.kubectl_path_documents.karpenter_resources.documents)
#   yaml_body = each.value

#   depends_on = [module.eks_blueprints_addons]
# }
