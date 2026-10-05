# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Bugs in the module before 1.0.0, each shown with a mocked test before it was fixed.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
}

variables {
  details = { scope = "Test", purpose = "Regressions", environment = "test" }
}

# The NAT gateways used to be a list: removing the first one moved the second to index
# 0, and since subnet_id forces replacement, the second NAT gateway and its address were
# replaced as well. Keyed by name, removing one leaves the others alone.
run "two_nat_gateways" {
  command = apply
  variables {
    nat_gateways = {
      a = { subnet_id = "subnet-0000000000000000a" }
      b = { subnet_id = "subnet-0000000000000000b" }
    }
  }
}

run "remove_one_keeps_the_other" {
  command = plan
  variables {
    nat_gateways = { b = { subnet_id = "subnet-0000000000000000b" } }
  }
  assert {
    condition = alltrue([
      keys(aws_nat_gateway.this) == ["b"],
      aws_nat_gateway.this["b"].id == run.two_nat_gateways.metadata.nat_gateway["b"].id,
      aws_eip.this["b"].allocation_id == run.two_nat_gateways.metadata.eip["b"].allocation_id,
    ])
    error_message = "Removing NAT gateway a must not change NAT gateway b or its address."
  }
}

# Multi-AZ routes were matched by Availability Zone. A private subnet in a zone with no
# NAT gateway got a route with nat_gateway_id = "", and of two NAT gateways in the same
# zone one got no traffic. Each route now names its NAT gateway.
run "route_goes_to_the_named_nat_gateway" {
  command = apply
  variables {
    nat_gateways = {
      a1 = { subnet_id = "subnet-0000000000000000a" }
      a2 = { subnet_id = "subnet-0000000000000000b" }
    }
    routes = {
      one = { route_table_id = "rtb-0000000000000000a", nat_gateway = "a1" }
      two = { route_table_id = "rtb-0000000000000000b", nat_gateway = "a2" }
    }
  }
  assert {
    condition = alltrue([
      aws_route.this["one"].nat_gateway_id == aws_nat_gateway.this["a1"].id,
      aws_route.this["two"].nat_gateway_id == aws_nat_gateway.this["a2"].id,
      aws_route.this["one"].nat_gateway_id != aws_route.this["two"].nat_gateway_id,
    ])
    error_message = "Each route must go to the NAT gateway it names."
  }
}

# The old module read the VPC's Name tag, and the plan failed for a VPC without one. The
# module now reads no VPC, so there is nothing to fail.
run "no_vpc_lookup" {
  command = plan
  variables {
    nat_gateways = { a = { subnet_id = "subnet-0000000000000000a" } }
  }
  assert {
    condition     = aws_nat_gateway.this["a"].tags["Name"] == "test-regressions-test-use1-a"
    error_message = "Unexpected Name tag."
  }
}

# Turning routes off (enable_routes = false) still required a list of private subnets.
# Routes are now an optional map; leaving it out creates none.
run "no_routes_needs_no_route_inputs" {
  command = plan
  variables {
    nat_gateways = { a = { subnet_id = "subnet-0000000000000000a" } }
  }
  assert {
    condition     = length(aws_route.this) == 0
    error_message = "Expected no routes."
  }
}
