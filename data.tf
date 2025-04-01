data "aws_vpc" "this" {
  id       = var.vpc_id
  provider = aws.this
}

data "aws_subnet" "nat_residency" {
  count    = (length(var.subnet_ids_nat_residency))
  vpc_id   = data.aws_vpc.this.id
  id       = var.subnet_ids_nat_residency[count.index]
  provider = aws.this
}

data "aws_subnet" "nat_usage" {
  count    = (length(var.subnet_ids_nat_usage))
  vpc_id   = data.aws_vpc.this.id
  id       = var.subnet_ids_nat_usage[count.index]
  provider = aws.this
}

data "aws_route_table" "nat_usage" {
  count     = (length(var.subnet_ids_nat_usage))
  vpc_id    = var.vpc_id
  subnet_id = data.aws_subnet.nat_usage[count.index].id
  provider  = aws.this
}
