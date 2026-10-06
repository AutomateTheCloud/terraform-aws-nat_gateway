# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A VPC, its subnets, its route table and an Elastic IP address created in the same run
# as the module. Their IDs are unknown at plan time, so the module must not decide
# count or for_each from them.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "details" {
  type = object({ scope = string, purpose = string, environment = string })
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.0.0/24"
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
}

resource "aws_eip" "kept" {
  domain = "vpc"
}

module "nat_gateway" {
  source = "../../.."

  details = var.details
  nat_gateways = {
    a = { subnet_id = aws_subnet.public.id }
    b = { subnet_id = aws_subnet.public.id, existing_eip = { allocation_id = aws_eip.kept.allocation_id } }
  }
  routes = {
    private = { route_table_id = aws_route_table.private.id, nat_gateway = "a" }
  }
}

output "metadata" {
  value = module.nat_gateway.metadata
}
