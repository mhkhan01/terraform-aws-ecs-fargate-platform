output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Availability Zones the subnets were placed in."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB, NAT gateway)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (Fargate tasks)."
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets."
  value       = local.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets."
  value       = local.private_subnet_cidrs
}

output "nat_gateway_count" {
  description = "Number of NAT gateways created (always 1 in this minimal module)."
  value       = 1
}
