variable "name" {
  description = "Name of the VPC and EKS Cluster"
  default     = "starrocks-eks-shared-data"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS version"
  default     = "1.29"
  type        = string
}

variable "eks_key_name" {
  description = "EKS managed nodes key name"
  default     = "0505"
  type        = string
}

variable "grafana_password" {
  description = "EKS managed nodes key name"
  default     = "admin"
  type        = string
}


variable "fe_count" {
  description = "fe instance number"
  default     = 1
  type        = number
}

