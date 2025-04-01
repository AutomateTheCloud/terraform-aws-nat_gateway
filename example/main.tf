terraform {
  required_version = "~> 1.11.0"
}

##-----------------------------------------------------------------------------
# Providers
provider "aws" {
  alias  = "example"
  region = "us-east-1"
}

##-----------------------------------------------------------------------------
# Module: NAT Gateway
module "nat_gateway" {
  source    = "../"
  providers = { aws.this = aws.example }

  details = {
    scope               = "Infrastructure"
    purpose             = "NAT Gateway"
    environment         = "prd"
    additional_tags = {
      "Project"         = "Project Name"
      "ProjectID"       = "123456789"
      "Contact"         = "David Singer - david.singer@example.com"
    }
  }

  vpc_id = "vpc-01234567891234567"

  subnet_ids_nat_residency = [
    "subnet-a1234567891234567", # public - AZ 1
    "subnet-b1234567891234567", # public - AZ 2
    "subnet-c1234567891234567"  # public - AZ 3
  ]

  subnet_ids_nat_usage  = [
    "subnet-d1234567891234567", # private - AZ 1
    "subnet-e1234567891234567", # private - AZ 2
    "subnet-f1234567891234567"  # private - AZ 3
  ]
}

##-----------------------------------------------------------------------------
# Outputs
output "metadata" {
  description = "Metadata"
  value = module.nat_gateway.metadata
}
