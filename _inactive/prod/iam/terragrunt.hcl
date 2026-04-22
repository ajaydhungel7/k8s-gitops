include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "eks_cluster" {
  config_path = "../eks-cluster"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/MOCK"
    oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "secrets" {
  config_path = "../secrets"

  mock_outputs = {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/mock-key-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../modules/iam"
}

inputs = {
  project     = include.root.locals.project
  environment = include.root.locals.env
  aws_region  = include.root.locals.region

  oidc_provider_arn = dependency.eks_cluster.outputs.oidc_provider_arn
  oidc_provider_url = dependency.eks_cluster.outputs.oidc_provider_url
  kms_key_arn       = dependency.secrets.outputs.kms_key_arn

  tags = {
    Project     = include.root.locals.project
    Environment = include.root.locals.env
    ManagedBy   = "terraform"
  }
}
