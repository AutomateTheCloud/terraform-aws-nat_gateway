# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The subnet, route table and Elastic IP address come from resources in the same run.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_resource "aws_subnet" {
    defaults = { id = "subnet-0123456789abcdef0" }
  }
  mock_resource "aws_route_table" {
    defaults = { id = "rtb-0123456789abcdef0" }
  }
  mock_resource "aws_eip" {
    defaults = { allocation_id = "eipalloc-0123456789abcdef0" }
  }
}

variables {
  details = { scope = "Test", purpose = "Same Run", environment = "test" }
}

run "plans_with_unknown_ids" {
  command = plan
  module {
    source = "./tests/fixtures/same_run"
  }
}

run "applies" {
  command = apply
  module {
    source = "./tests/fixtures/same_run"
  }
  assert {
    condition = alltrue([
      keys(output.metadata.eip) == ["a"],
      output.metadata.nat_gateway["b"].allocation_id == "eipalloc-0123456789abcdef0",
      output.metadata.route["private"].nat_gateway_id == output.metadata.nat_gateway["a"].id,
    ])
    error_message = "Unexpected result with same-run inputs."
  }
}
