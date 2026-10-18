output "service_url" {
  description = "URL to open once tasks are healthy."
  value       = "${module.alb.https_enabled ? "https" : "http"}://${module.alb.alb_dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the ALB (point a CNAME or alias record here)."
  value       = module.alb.alb_dns_name
}

output "vpc_id" {
  description = "ID of the example VPC."
  value       = module.network.vpc_id
}

output "public_subnet_cidrs" {
  description = "CIDRs of the public subnets."
  value       = module.network.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "CIDRs of the private subnets."
  value       = module.network.private_subnet_cidrs
}

output "availability_zones" {
  description = "Availability Zones in use."
  value       = module.network.availability_zones
}

output "nat_gateway_count" {
  description = "Number of NAT gateways."
  value       = module.network.nat_gateway_count
}

output "http_listener_action" {
  description = "What the port-80 listener does: redirect (HTTPS on) or forward (demo mode)."
  value       = module.alb.http_listener_action
}

output "https_enabled" {
  description = "Whether the HTTPS listener exists."
  value       = module.alb.https_enabled
}

output "https_ingress_rule_count" {
  description = "Number of 443 ingress rules on the ALB SG."
  value       = module.alb.https_ingress_rule_count
}

output "waf_enabled" {
  description = "Whether WAF is associated."
  value       = module.alb.waf_enabled
}

output "access_log_bucket" {
  description = "S3 bucket holding ALB access logs."
  value       = module.alb.access_log_bucket
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs_service.cluster_name
}

output "service_name" {
  description = "ECS service name."
  value       = module.ecs_service.service_name
}

output "ecr_repository_url" {
  description = "Push the app/ image here."
  value       = module.ecs_service.ecr_repository_url
}

output "log_group_name" {
  description = "CloudWatch log group for container logs."
  value       = module.ecs_service.log_group_name
}

output "container_definition" {
  description = "Rendered container definition."
  value       = module.ecs_service.container_definition
}

output "capacity_provider_strategy" {
  description = "Fargate / Fargate Spot weights."
  value       = module.ecs_service.capacity_provider_strategy
}

output "autoscaling_policy_names" {
  description = "Target-tracking policy names."
  value       = module.ecs_service.autoscaling_policy_names
}

output "alarm_names" {
  description = "CloudWatch alarm names."
  value       = module.ecs_service.alarm_names
}

output "alarm_topic_arn" {
  description = "SNS topic for alarms; subscribe an email or chat integration to it."
  value       = module.ecs_service.alarm_topic_arn
}

output "execute_command_enabled" {
  description = "Whether ECS Exec is on."
  value       = module.ecs_service.execute_command_enabled
}
