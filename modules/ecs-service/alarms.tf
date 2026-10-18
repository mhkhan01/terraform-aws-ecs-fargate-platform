resource "aws_sns_topic" "alarms" {
  count = var.create_alarm_topic ? 1 : 0

  name              = "${local.name}-alarms"
  kms_master_key_id = aws_kms_key.this.arn

  tags = local.tags
}

locals {
  alarm_actions = concat(aws_sns_topic.alarms[*].arn, var.alarm_actions)

  alb_dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name}-target-5xx"
  alarm_description   = "Tasks behind the ALB returned more than ${var.alarm_5xx_threshold} 5xx responses per minute."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = local.alb_dimensions
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = var.alarm_5xx_threshold
  comparison_operator = "GreaterThanThreshold"
  # No traffic means no 5xx, not an unknown state.
  treat_missing_data = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name}-unhealthy-hosts"
  alarm_description   = "At least one target is failing ALB health checks."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = local.alb_dimensions
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name}-cpu-high"
  alarm_description   = "Service CPU above ${var.alarm_cpu_threshold}% for 5 minutes; auto scaling may be at max capacity."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.alarm_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.this.name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = local.tags
}
