locals {
  path_parts = split("/", path_relative_to_include())
  env        = local.path_parts[1]
  region     = "us-east-1"
  project    = "k8s-gitops"
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "k8s-gitops-terraform-state"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    encrypt      = true
    use_lockfile = true
  }
}
