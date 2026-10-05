# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# One NAT gateway that gives a private subnet access to the internet. The VPC is built
# here from plain resources so the example stands alone: a public subnet with a route
# to an internet gateway, where the NAT gateway goes, and a private subnet whose route
# table sends 0.0.0.0/0 to the NAT gateway.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  details = {
    scope       = "Example"
    purpose     = "Basic NAT Gateway"
    environment = "Development"
  }
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_vpc" "this" {
  cidr_block = "10.40.0.0/16"
  tags       = { Name = "example-basic-nat-gateway" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

# Public subnet: the NAT gateway's home. Its route table sends 0.0.0.0/0 to the
# internet gateway.
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.40.0.0/24"
  availability_zone = local.availability_zone
  tags              = { Name = "example-basic-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "example-basic-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private subnet: instances here have no public address. The module adds the route
# from this route table to the NAT gateway.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.40.10.0/24"
  availability_zone = local.availability_zone
  tags              = { Name = "example-basic-private" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "example-basic-private" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

module "nat_gateway" {
  source = "../../"

  details = local.details

  nat_gateways = {
    a = { subnet_id = aws_subnet.public.id }
  }

  routes = {
    private = { route_table_id = aws_route_table.private.id, nat_gateway = "a" }
  }

  # AWS recommends creating a public NAT gateway only once the VPC has an internet
  # gateway; the module does not know about it, so the dependency is set here.
  depends_on = [aws_internet_gateway.this]
}

output "nat_gateway_public_ip" {
  description = "The address that traffic from the private subnet comes from on the internet"
  value       = module.nat_gateway.metadata.nat_gateway["a"].public_ip
}
