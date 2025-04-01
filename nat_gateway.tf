resource "aws_nat_gateway" "this" {
  count         = (length(var.subnet_ids_nat_residency))
  allocation_id = (local.multi_az_enabled ? aws_eip.this[count.index].id : aws_eip.this[0].id)
  subnet_id     = data.aws_subnet.nat_residency[count.index].id
  tags = merge(
    local.tags,
    tomap({
      "Name" = "${data.aws_vpc.this.tags["Name"]}${local.multi_az_enabled ? ("-${count.index + 1}") : ""}"
    })
  )
  provider = aws.this
}
