locals {
  multi_az_enabled            = (length(var.subnet_ids_nat_residency) > 1 ? true : false)
  nat_gateway_map             = zipmap(aws_nat_gateway.this[*].subnet_id, aws_nat_gateway.this[*].id)
  subnet_nat_residency_az_map = zipmap(data.aws_subnet.nat_residency[*].availability_zone, data.aws_subnet.nat_residency[*].id)
}
