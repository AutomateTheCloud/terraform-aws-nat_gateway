# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# One Elastic IP address for each public NAT gateway that does not bring its own.
resource "aws_eip" "this" {
  for_each = local.eips
  region   = var.region

  domain = "vpc"

  tags = merge(local.tags, { Name = local.nat_gateway_names[each.key] })
}
