module "poc_pc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "soar-vpc"
  cidr = "10.0.0.0/22"

  azs             = ["eu-central-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.0.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}