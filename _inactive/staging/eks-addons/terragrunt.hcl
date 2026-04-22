include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "eks_cluster" {
  config_path = "../eks-cluster"

  mock_outputs = {
    cluster_name           = "mock-cluster"
    cluster_endpoint       = "https://mock.eks.amazonaws.com"
    cluster_ca_certificate = "bW9jaw=="
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../modules/eks-addons"
}

inputs = {
  cluster_name           = dependency.eks_cluster.outputs.cluster_name
  cluster_endpoint       = dependency.eks_cluster.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.eks_cluster.outputs.cluster_ca_certificate

  tags = {
    Project     = include.root.locals.project
    Environment = include.root.locals.env
    ManagedBy   = "terraform"
  }
}
