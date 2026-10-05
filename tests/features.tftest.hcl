# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_resource "aws_eip" {
    defaults = { allocation_id = "eipalloc-0123456789abcdef0" }
  }
}

variables {
  details = { scope = "Test", purpose = "Features", environment = "test" }
}

# Three Availability Zones, each private route table sent to the NAT gateway in its own zone.
run "one_nat_gateway_per_zone" {
  command = apply
  variables {
    nat_gateways = {
      a = { subnet_id = "subnet-0000000000000000a" }
      b = { subnet_id = "subnet-0000000000000000b" }
      c = { subnet_id = "subnet-0000000000000000c" }
    }
    routes = {
      private_a = { route_table_id = "rtb-0000000000000000a", nat_gateway = "a" }
      private_b = { route_table_id = "rtb-0000000000000000b", nat_gateway = "b" }
      private_c = { route_table_id = "rtb-0000000000000000c", nat_gateway = "c" }
    }
  }
  assert {
    condition = alltrue([
      length(aws_eip.this) == 3,
      aws_route.this["private_a"].nat_gateway_id == aws_nat_gateway.this["a"].id,
      aws_route.this["private_b"].nat_gateway_id == aws_nat_gateway.this["b"].id,
      aws_route.this["private_c"].nat_gateway_id == aws_nat_gateway.this["c"].id,
      aws_route.this["private_a"].route_table_id == "rtb-0000000000000000a",
      aws_route.this["private_a"].destination_cidr_block == "0.0.0.0/0",
      output.metadata.route["private_b"].nat_gateway_id == aws_nat_gateway.this["b"].id,
    ])
    error_message = "Each route must go to the NAT gateway it names."
  }
}

# One NAT gateway shared by every route table, to save cost where zone failures are acceptable.
run "single_nat_gateway" {
  command = apply
  variables {
    nat_gateways = { shared = { subnet_id = "subnet-0000000000000000a" } }
    routes = {
      private_a = { route_table_id = "rtb-0000000000000000a", nat_gateway = "shared" }
      private_b = { route_table_id = "rtb-0000000000000000b", nat_gateway = "shared" }
    }
  }
  assert {
    condition = alltrue([
      length(aws_nat_gateway.this) == 1,
      aws_route.this["private_a"].nat_gateway_id == aws_nat_gateway.this["shared"].id,
      aws_route.this["private_b"].nat_gateway_id == aws_nat_gateway.this["shared"].id,
    ])
    error_message = "Both routes must go to the shared NAT gateway."
  }
}

run "existing_eip" {
  command = plan
  variables {
    nat_gateways = { a = { subnet_id = "subnet-0000000000000000a", existing_eip = { allocation_id = "eipalloc-0fedcba9876543210" } } }
  }
  assert {
    condition = alltrue([
      length(aws_eip.this) == 0,
      aws_nat_gateway.this["a"].allocation_id == "eipalloc-0fedcba9876543210",
      output.metadata.eip == null,
    ])
    error_message = "An existing Elastic IP address must be used, and none created."
  }
}

run "private_nat_gateway" {
  command = plan
  variables {
    nat_gateways = { transit = { subnet_id = "subnet-0000000000000000a", connectivity_type = "private" } }
    routes = {
      to_on_premises = { route_table_id = "rtb-0000000000000000a", nat_gateway = "transit", destination_cidr_block = "10.20.0.0/16" }
    }
  }
  assert {
    condition = alltrue([
      length(aws_eip.this) == 0,
      aws_nat_gateway.this["transit"].connectivity_type == "private",
      aws_nat_gateway.this["transit"].allocation_id == null,
      aws_route.this["to_on_premises"].destination_cidr_block == "10.20.0.0/16",
    ])
    error_message = "A private NAT gateway must have no Elastic IP address."
  }
}

run "custom_name" {
  command = plan
  variables {
    nat_gateways = { a = { subnet_id = "subnet-0000000000000000a", name = "egress-a" } }
  }
  assert {
    condition     = aws_nat_gateway.this["a"].tags["Name"] == "egress-a" && aws_eip.this["a"].tags["Name"] == "egress-a"
    error_message = "The name must be used for the NAT gateway and its Elastic IP address."
  }
}

# Mixed: one public NAT gateway with a new address, one with an existing one, one private.
run "mixed" {
  command = plan
  variables {
    nat_gateways = {
      new      = { subnet_id = "subnet-0000000000000000a" }
      existing = { subnet_id = "subnet-0000000000000000b", existing_eip = { allocation_id = "eipalloc-0fedcba9876543210" } }
      private  = { subnet_id = "subnet-0000000000000000c", connectivity_type = "private" }
    }
  }
  assert {
    condition     = keys(aws_eip.this) == ["new"]
    error_message = "Only the public NAT gateway without an existing_eip gets a new Elastic IP address."
  }
}
