# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A route to a NAT gateway in each route table listed. for_each uses the map keys, which
# come from the inputs, so a route table created in the same run still plans.
resource "aws_route" "this" {
  for_each = var.routes
  region   = var.region

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination_cidr_block
  nat_gateway_id         = aws_nat_gateway.this[each.value.nat_gateway].id
}
