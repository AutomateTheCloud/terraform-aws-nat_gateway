# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# One NAT gateway for each entry in var.nat_gateways. for_each uses the map keys, which
# come from the inputs, so removing one NAT gateway leaves the others alone.
resource "aws_nat_gateway" "this" {
  for_each = var.nat_gateways
  region   = var.region

  subnet_id         = each.value.subnet_id
  connectivity_type = each.value.connectivity_type
  allocation_id = (
    each.value.connectivity_type != "public" ? null :
    each.value.existing_eip != null ? each.value.existing_eip.allocation_id :
    aws_eip.this[each.key].allocation_id
  )

  tags = merge(local.tags, { Name = local.nat_gateway_names[each.key] })
}
