# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
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
  details      = { scope = "Test", purpose = "Defaults", environment = "test" }
  nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0" } }
}

# With only the required inputs: one public NAT gateway with its own Elastic IP address,
# and no routes, so no route table sends traffic to it until one is listed.
run "defaults" {
  command = apply

  assert {
    condition = alltrue([
      length(aws_nat_gateway.this) == 1,
      aws_nat_gateway.this["a"].subnet_id == "subnet-0123456789abcdef0",
      aws_nat_gateway.this["a"].connectivity_type == "public",
      aws_nat_gateway.this["a"].allocation_id == aws_eip.this["a"].allocation_id,
      aws_nat_gateway.this["a"].allocation_id == "eipalloc-0123456789abcdef0",
      length(aws_eip.this) == 1,
      aws_eip.this["a"].domain == "vpc",
      length(aws_route.this) == 0,
    ])
    error_message = "Expected one public NAT gateway with a new Elastic IP address and no routes."
  }
  assert {
    condition = alltrue([
      output.metadata.nat_gateway["a"].id == aws_nat_gateway.this["a"].id,
      output.metadata.eip["a"].allocation_id == "eipalloc-0123456789abcdef0",
      output.metadata.route == null,
      # Regression: these are empty when the address is created and filled in once the
      # NAT gateway is attached, so every plan after an apply showed the output changing.
      !can(output.metadata.eip["a"].association_id),
      !can(output.metadata.eip["a"].network_interface),
      !can(output.metadata.eip["a"].private_ip),
      # Regression: provider 6.0.0 saves this as null and reads it back as [].
      !can(output.metadata.nat_gateway["a"].secondary_allocation_ids),
      output.metadata.aws.region.name == "us-east-1",
      output.metadata.aws.region.abbr == "use1",
      output.metadata.aws.account.id == "111111111111",
    ])
    error_message = "Unexpected metadata output."
  }
}

run "tags" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Defaults", environment = "test", additional_tags = { CostCenter = "1234" } }
  }
  assert {
    condition = aws_nat_gateway.this["a"].tags == tomap({
      Scope       = "Test"
      Purpose     = "Defaults"
      Environment = "test"
      CostCenter  = "1234"
      Name        = "test-defaults-test-use1-a"
    })
    error_message = "Unexpected NAT gateway tags."
  }
  assert {
    condition     = aws_eip.this["a"].tags == aws_nat_gateway.this["a"].tags
    error_message = "The Elastic IP address must be tagged like its NAT gateway."
  }
}

# Regression: an empty abbreviation override used to replace the generated one with "",
# so the Name tag started with a hyphen.
run "abbreviation_override" {
  command = plan
  variables {
    details = { scope = "Automate the Cloud", scope_abbr = "atc-org", purpose = "NAT Gateway", purpose_abbr = "", environment = "Production" }
  }
  assert {
    condition = alltrue([
      output.metadata.details.scope.abbr == "atc-org",
      output.metadata.details.scope.machine == "atcorg",
      output.metadata.details.purpose.abbr == "nat_gateway",
      output.metadata.details.purpose.machine == "natgateway",
      aws_nat_gateway.this["a"].tags["Name"] == "atc-org-nat_gateway-production-use1-a",
    ])
    error_message = "Unexpected abbreviations."
  }
}

run "details_scope_required" {
  command = plan
  variables { details = { scope = " ", purpose = "p", environment = "e" } }
  expect_failures = [var.details]
}

run "details_purpose_required" {
  command = plan
  variables { details = { scope = "s", purpose = "", environment = "e" } }
  expect_failures = [var.details]
}

run "details_environment_required" {
  command = plan
  variables { details = { scope = "s", purpose = "p", environment = "" } }
  expect_failures = [var.details]
}
