# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
}

variables {
  details      = { scope = "Test", purpose = "Validation", environment = "test" }
  nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0" } }
}

run "nat_gateways_empty" {
  command = plan
  variables { nat_gateways = {} }
  expect_failures = [var.nat_gateways]
}

run "nat_gateways_bad_key" {
  command = plan
  variables { nat_gateways = { "zone a" = { subnet_id = "subnet-0123456789abcdef0" } } }
  expect_failures = [var.nat_gateways]
}

run "subnet_id_invalid" {
  command = plan
  variables { nat_gateways = { a = { subnet_id = "0123456789abcdef0" } } }
  expect_failures = [var.nat_gateways]
}

run "subnet_id_short_form_accepted" {
  command = plan
  variables { nat_gateways = { a = { subnet_id = "subnet-01234567" } } }
}

run "connectivity_type_invalid" {
  command = plan
  variables { nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0", connectivity_type = "Public" } } }
  expect_failures = [var.nat_gateways]
}

run "existing_eip_on_private" {
  command = plan
  variables {
    nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0", connectivity_type = "private", existing_eip = { allocation_id = "eipalloc-0123456789abcdef0" } } }
  }
  expect_failures = [var.nat_gateways]
}

run "existing_eip_invalid" {
  command = plan
  variables { nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0", existing_eip = { allocation_id = "203.0.113.10" } } } }
  expect_failures = [var.nat_gateways]
}

run "existing_eip_twice" {
  command = plan
  variables {
    nat_gateways = {
      a = { subnet_id = "subnet-0000000000000000a", existing_eip = { allocation_id = "eipalloc-0123456789abcdef0" } }
      b = { subnet_id = "subnet-0000000000000000b", existing_eip = { allocation_id = "eipalloc-0123456789abcdef0" } }
    }
  }
  expect_failures = [var.nat_gateways]
}

run "name_empty" {
  command = plan
  variables { nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0", name = " " } } }
  expect_failures = [var.nat_gateways]
}

run "name_too_long" {
  command = plan
  variables { nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0", name = join("", [for i in range(257) : "n"]) } } }
  expect_failures = [var.nat_gateways]
}

run "route_table_id_invalid" {
  command = plan
  variables { routes = { r = { route_table_id = "subnet-0123456789abcdef0", nat_gateway = "a" } } }
  expect_failures = [var.routes]
}

run "route_unknown_nat_gateway" {
  command = plan
  variables { routes = { r = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "b" } } }
  expect_failures = [var.routes]
}

run "destination_not_cidr" {
  command = plan
  variables { routes = { r = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a", destination_cidr_block = "10.20.0.0" } } }
  expect_failures = [var.routes]
}

run "destination_ipv6" {
  command = plan
  variables { routes = { r = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a", destination_cidr_block = "64:ff9b::/96" } } }
  expect_failures = [var.routes]
}

run "destination_host_bits" {
  command = plan
  variables { routes = { r = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a", destination_cidr_block = "10.20.1.0/16" } } }
  expect_failures = [var.routes]
}

# Regression: two private subnets sharing a route table got two 0.0.0.0/0 routes in it,
# and the second failed at apply. Listing a route table twice now fails at plan time.
run "duplicate_route" {
  command = plan
  variables {
    routes = {
      r1 = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a" }
      r2 = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a" }
    }
  }
  expect_failures = [var.routes]
}

run "same_table_other_destination_accepted" {
  command = plan
  variables {
    routes = {
      r1 = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a" }
      r2 = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a", destination_cidr_block = "10.20.0.0/16" }
    }
  }
}
