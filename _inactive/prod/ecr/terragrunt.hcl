include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
  project = include.root.locals.project

  tags = {
    Project     = include.root.locals.project
    Environment = include.root.locals.env
    ManagedBy   = "terraform"
  }
}
