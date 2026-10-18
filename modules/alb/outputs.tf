output "alb_arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the load balancer, used for CloudWatch metrics and auto scaling."
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Route 53 hosted zone ID of the load balancer, for alias records."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the IP target group the ECS service registers into."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group, used for CloudWatch metrics and auto scaling."
  value       = aws_lb_target_group.this.arn_suffix
}

output "alb_security_group_id" {
  description = "Security group attached to the ALB."
  value       = aws_security_group.alb.id
}

output "service_security_group_id" {
  description = "Security group for the ECS tasks; only the ALB can reach the container port."
  value       = aws_security_group.service.id
}

output "http_listener_action" {
  description = "Default action of the port-80 listener: 'redirect' when HTTPS is enabled, otherwise 'forward'."
  value       = aws_lb_listener.http.default_action[0].type
}

output "https_enabled" {
  description = "Whether an HTTPS listener was created."
  value       = length(aws_lb_listener.https) == 1
}

output "https_ingress_rule_count" {
  description = "Number of 443 ingress rules on the ALB security group."
  value       = length(aws_vpc_security_group_ingress_rule.alb_https)
}

output "waf_enabled" {
  description = "Whether a WAFv2 web ACL is associated with the ALB."
  value       = length(aws_wafv2_web_acl_association.this) == 1
}

output "access_log_bucket" {
  description = "Name of the S3 bucket receiving ALB access logs."
  value       = aws_s3_bucket.logs.bucket
}
