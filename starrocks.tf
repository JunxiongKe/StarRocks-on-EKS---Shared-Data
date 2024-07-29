resource "helm_release" "starrocks_operator" {

  name                       = "starrocks-community"
  repository                 = local.starrocks_operator_repository
  chart                      = "kube-starrocks"
  namespace                  = "starrocks"
  create_namespace           = true

  wait = true

  depends_on = [kubernetes_storage_class.ebs_csi_encrypted_gp3_storage_class]
  
  values = [
    templatefile("${path.module}/helm-values/starrocks-values.yaml",{
      STARROCKS_HOME = "/opt/starrocks"
    })
    ]
}
