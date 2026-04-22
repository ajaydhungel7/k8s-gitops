locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    public_subnet_ids  = ["subnet-mock1", "subnet-mock2"]
    private_subnet_ids = ["subnet-mock3", "subnet-mock4"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../modules/eks-cluster"
}

inputs = {
  project     = include.root.locals.project
  environment = include.root.locals.env

  public_subnet_ids  = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  node_instance_type = local.env_vars.locals.node_instance_type
  node_min_size      = local.env_vars.locals.node_min_size
  node_max_size      = local.env_vars.locals.node_max_size
  node_desired_size  = local.env_vars.locals.node_desired_size

  tags = {
    Project     = include.root.locals.project
    Environment = include.root.locals.env
    ManagedBy   = "terraform"
  }
}
