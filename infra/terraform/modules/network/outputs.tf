output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.this[*].id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.this.id
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}
