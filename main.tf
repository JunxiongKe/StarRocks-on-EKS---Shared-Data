#---------------------------------------------------------------
# EKS Module
#---------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.21"

  cluster_name    = var.name
  cluster_version = var.eks_cluster_version
  
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # manage_aws_auth_configmap = true

  eks_managed_node_groups = {
    starrocks_node_group = {
      min_size     = 4
      max_size     = 4
      desired_size = 4

      instance_types = ["c6i.16xlarge"]

      # ami_type = "AL2023_ARM_64_STANDARD"

      key_name = "0505"

      ebs_optimized = true
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 200
            volume_type = "gp3"
          }
        }
      }
    }
  }
}
