# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A NAT gateway in each of two Availability Zones, each serving the private subnet in
# its own zone, so that a problem in one zone does not cut off the other. NAT gateway
# "a" uses an Elastic IP address created outside the module, which stays the same when
# the NAT gateway is replaced and is kept when the module is destroyed: use one for an
# address that a partner has on an allow list. NAT gateway "b" gets its address from
# the module, and both have a chosen Name tag.

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
    purpose     = "Complete NAT Gateway"
    environment = "Development"
    additional_tags = {
      CostCenter = "1234"
    }
  }

  # The first two Availability Zones in the Region, with a public and a private
  # subnet in each.
  zones = {
    a = { availability_zone = data.aws_availability_zones.available.names[0], public = "10.50.0.0/24", private = "10.50.10.0/24" }
    b = { availability_zone = data.aws_availability_zones.available.names[1], public = "10.50.1.0/24", private = "10.50.11.0/24" }
  }
}

resource "aws_vpc" "this" {
  cidr_block = "10.50.0.0/16"
  tags       = { Name = "example-complete-nat-gateway" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "public" {
  for_each = local.zones

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.public
  availability_zone = each.value.availability_zone
  tags              = { Name = "example-complete-public-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "example-complete-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = local.zones

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# One private subnet and route table per zone, so each can use its own zone's NAT gateway.
resource "aws_subnet" "private" {
  for_each = local.zones

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.private
  availability_zone = each.value.availability_zone
  tags              = { Name = "example-complete-private-${each.key}" }
}

resource "aws_route_table" "private" {
  for_each = local.zones

  vpc_id = aws_vpc.this.id
  tags   = { Name = "example-complete-private-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each = local.zones

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

# An address managed outside the module.
resource "aws_eip" "a" {
  domain = "vpc"
  tags   = { Name = "example-complete-nat-a" }
}

module "nat_gateway" {
  source = "../../"

  details = local.details

  nat_gateways = {
    a = {
      subnet_id    = aws_subnet.public["a"].id
      existing_eip = { allocation_id = aws_eip.a.allocation_id }
      name         = "example-complete-nat-a"
    }
    b = {
      subnet_id = aws_subnet.public["b"].id
      name      = "example-complete-nat-b"
    }
  }

  # Each private route table to the NAT gateway in its own zone.
  routes = {
    for k in keys(local.zones) : "private_${k}" => {
      route_table_id = aws_route_table.private[k].id
      nat_gateway    = k
    }
  }

  depends_on = [aws_internet_gateway.this]
}

output "nat_gateway_public_ips" {
  description = "The address that traffic from each zone's private subnet comes from on the internet"
  value       = { for k, v in module.nat_gateway.metadata.nat_gateway : k => v.public_ip }
}
