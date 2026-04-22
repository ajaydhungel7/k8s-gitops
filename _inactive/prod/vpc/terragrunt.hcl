locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  project     = include.root.locals.project
  environment = include.root.locals.env

  vpc_cidr             = local.env_vars.locals.vpc_cidr
  public_subnet_cidrs  = local.env_vars.locals.public_subnets
  private_subnet_cidrs = local.env_vars.locals.private_subnets
  availability_zones   = local.env_vars.locals.azs

  tags = {
    Project     = include.root.locals.project
    Environment = include.root.locals.env
    ManagedBy   = "terraform"
  }
}
