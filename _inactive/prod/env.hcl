locals {
  vpc_cidr         = "10.2.0.0/16"
  public_subnets   = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnets  = ["10.2.10.0/24", "10.2.11.0/24"]
  azs              = ["us-east-1a", "us-east-1b"]

  node_instance_type = "t3.large"
  node_min_size      = 3
  node_max_size      = 10
  node_desired_size  = 4
}
