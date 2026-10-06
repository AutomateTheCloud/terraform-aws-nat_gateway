# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
}

variables {
  details      = { scope = "Test", purpose = "Region", environment = "test" }
  nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0" } }
  routes       = { private_a = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a" } }
}

# The module uses the default aws provider: no providers block is needed.
run "provider_region_by_default" {
  command = plan
  assert {
    condition     = output.metadata.aws.region.name == "us-east-1"
    error_message = "Expected the provider's Region."
  }
}

run "region_reaches_every_resource" {
  command = apply
  variables { region = "us-west-2" }
  assert {
    condition = alltrue([
      aws_eip.this["a"].region == "us-west-2",
      aws_nat_gateway.this["a"].region == "us-west-2",
      aws_route.this["private_a"].region == "us-west-2",
      output.metadata.nat_gateway["a"].region == "us-west-2",
      output.metadata.aws.region.name == "us-west-2",
      output.metadata.aws.region.abbr == "usw2",
      aws_nat_gateway.this["a"].tags["Name"] == "test-region-test-usw2-a",
    ])
    error_message = "region was not passed through to every resource."
  }
}

# Regression: the old hard-coded Region table failed the plan in any Region missing
# from it, such as ap-east-2 (Taipei).
run "region_abbreviation_not_in_old_table" {
  command = plan
  variables { region = "ap-east-2" }
  assert {
    condition     = output.metadata.aws.region.abbr == "ape2" && aws_nat_gateway.this["a"].tags["Name"] == "test-region-test-ape2-a"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_new_region" {
  command = plan
  variables { region = "ca-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "caw1"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_override" {
  command = plan
  variables { region = "us-gov-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "ugw1"
    error_message = "Unexpected abbreviation."
  }
}
