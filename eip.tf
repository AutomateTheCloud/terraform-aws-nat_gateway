resource "aws_eip" "this" {
  count = (length(var.subnet_ids_nat_residency))
  domain = "vpc"
  tags = merge(
    local.tags,
    tomap({
      "Name" = "nat_gateway-${data.aws_vpc.this.tags["Name"]}${local.multi_az_enabled ? ("-${count.index + 1}") : ""}"
    })
  )
  provider = aws.this
}
