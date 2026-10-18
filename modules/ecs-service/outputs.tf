output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "task_definition_family" {
  description = "Task definition family; each apply with a new image registers a new revision."
  value       = aws_ecs_task_definition.this.family
}

output "task_size" {
  description = "Task CPU units and memory (MiB)."
  value       = { cpu = var.cpu, memory = var.memory }
}

output "container_definition" {
  description = "The rendered container definition, useful for review and tests."
  value       = local.container_definition
}

output "ecr_repository_url" {
  description = "URL to tag and push images to."
  value       = aws_ecr_repository.this.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.this.arn
}

output "kms_key_arn" {
  description = "ARN of the customer managed key used for ECR, logs, ECS Exec and SNS."
  value       = aws_kms_key.this.arn
}

output "log_group_name" {
  description = "CloudWatch log group receiving container stdout/stderr."
  value       = aws_cloudwatch_log_group.app.name
}

output "execution_role_arn" {
  description = "ARN of the task execution role (ECS agent)."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the task role (application code)."
  value       = aws_iam_role.task.arn
}

output "capacity_provider_strategy" {
  description = "Capacity provider weights and base applied to the service."
  value       = local.capacity_provider_strategy
}

output "autoscaling_policy_names" {
  description = "Names of the target-tracking scaling policies (empty when auto scaling is disabled)."
  value       = concat(aws_appautoscaling_policy.cpu[*].name, aws_appautoscaling_policy.requests[*].name)
}

output "alarm_names" {
  description = "Names of the CloudWatch alarms created."
  value = concat(
    aws_cloudwatch_metric_alarm.target_5xx[*].alarm_name,
    aws_cloudwatch_metric_alarm.unhealthy_hosts[*].alarm_name,
    aws_cloudwatch_metric_alarm.cpu_high[*].alarm_name,
  )
}

output "alarm_topic_arn" {
  description = "ARN of the alarm SNS topic, or null when create_alarm_topic is false."
  value       = try(aws_sns_topic.alarms[0].arn, null)
}

output "execute_command_enabled" {
  description = "Whether ECS Exec is enabled on the service."
  value       = aws_ecs_service.this.enable_execute_command
}
