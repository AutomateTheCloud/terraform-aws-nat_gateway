resource "aws_route" "this" {
  count                  = var.enable_routes ? length(var.subnet_ids_nat_usage) : 0
  route_table_id         = data.aws_route_table.nat_usage[count.index].route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = (
    local.multi_az_enabled ?
    lookup(local.nat_gateway_map, lookup(local.subnet_nat_residency_az_map, data.aws_subnet.nat_usage[count.index].availability_zone, ""), "")
    :
    aws_nat_gateway.this[0].id
  )
  provider = aws.this
}
