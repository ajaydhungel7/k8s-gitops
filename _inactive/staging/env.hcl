locals {
  vpc_cidr         = "10.1.0.0/16"
  public_subnets   = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets  = ["10.1.10.0/24", "10.1.11.0/24"]
  azs              = ["us-east-1a", "us-east-1b"]

  node_instance_type = "t3.large"
  node_min_size      = 2
  node_max_size      = 5
  node_desired_size  = 3
}
