# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  # The Name tag of each NAT gateway, and of the Elastic IP address created for it:
  # <scope>-<purpose>-<environment>-<region>-<key> unless the input names it.
  nat_gateway_names = {
    for k, v in var.nat_gateways : k => v.name != null ? v.name : "${local.scope.abbr}-${local.purpose.abbr}-${local.environment.abbr}-${local.aws.region.abbr}-${k}"
  }

  # The public NAT gateways that need an Elastic IP address from the module. This tests
  # whether existing_eip is null, not its allocation_id, so an address created in the
  # same run still plans.
  eips = {
    for k, v in var.nat_gateways : k => v if v.connectivity_type == "public" && v.existing_eip == null
  }
}
