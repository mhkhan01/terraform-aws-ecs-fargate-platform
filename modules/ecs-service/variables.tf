################################################################################
# Identity and placement
################################################################################

variable "name" {
  description = "Name used for the cluster, service, task family, ECR repository and log groups."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3-32 chars, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "private_subnet_ids" {
  description = "Private subnets the tasks run in. Tasks never get public IPs."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Provide private subnets in at least two Availability Zones."
  }
}

variable "security_group_ids" {
  description = "Security groups attached to the task ENIs (normally the service SG from the alb module)."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group is required."
  }
}

variable "target_group_arn" {
  description = "ALB target group (type ip) the service registers tasks into."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix, used for RequestCountPerTarget scaling and ALB alarms."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix, used for RequestCountPerTarget scaling and ALB alarms."
  type        = string
}

################################################################################
# Container
################################################################################

variable "container_name" {
  description = "Name of the container inside the task definition."
  type        = string
  default     = "app"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.container_name))
    error_message = "container_name may contain letters, digits, hyphens and underscores only."
  }
}

variable "container_image" {
  description = "Full image reference, e.g. an ECR URI with an immutable tag or a public.ecr.aws image."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "container_user" {
  description = "UID[:GID] the container runs as. Defaults to a non-root user; set null only for images that cannot run unprivileged."
  type        = string
  default     = "1000:1000"

  validation {
    condition     = var.container_user == null || !contains(["root", "0", "0:0", "root:root"], coalesce(var.container_user, "x"))
    error_message = "container_user must not be root. Set null to fall back to the image default instead."
  }
}

variable "readonly_root_filesystem" {
  description = "Mount the container root filesystem read-only. Pair with writable_paths for software that needs scratch space."
  type        = bool
  default     = true
}

variable "writable_paths" {
  description = "Container paths that get a task-scoped writable volume (for example /tmp) so a read-only root filesystem still works."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for p in var.writable_paths : startswith(p, "/")])
    error_message = "writable_paths must be absolute paths."
  }
}

variable "environment" {
  description = "Plain-text environment variables. Never put secrets here; use secrets instead."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets injected as environment variables at start-up. value_from must be an SSM Parameter Store or Secrets Manager ARN."
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.secrets : can(regex("^arn:aws[a-z-]*:(ssm|secretsmanager):[a-z0-9-]+:[0-9]{12}:", s.value_from))
    ])
    error_message = "Each secrets[*].value_from must be a full SSM parameter or Secrets Manager ARN."
  }
}

variable "secrets_kms_key_arns" {
  description = "Customer managed KMS keys that encrypt the referenced secrets, if not the AWS managed default."
  type        = list(string)
  default     = []
}

variable "task_role_policy_arns" {
  description = "IAM policies to attach to the task (application) role, keyed by a static name."
  type        = map(string)
  default     = {}
}

################################################################################
# Task sizing
################################################################################

variable "cpu" {
  description = "Task CPU units. Must be a Fargate size: 256, 512, 1024, 2048, 4096, 8192 or 16384."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu)
    error_message = "cpu must be one of 256, 512, 1024, 2048, 4096, 8192, 16384."
  }
}

variable "memory" {
  description = "Task memory in MiB. Must be a valid Fargate pairing for the chosen cpu."
  type        = number
  default     = 512

  # Valid Fargate CPU/memory combinations, per the ECS developer guide.
  validation {
    condition = contains(lookup({
      "256"   = [512, 1024, 2048]
      "512"   = range(1024, 4097, 1024)
      "1024"  = range(2048, 8193, 1024)
      "2048"  = range(4096, 16385, 1024)
      "4096"  = range(8192, 30721, 1024)
      "8192"  = range(16384, 61441, 4096)
      "16384" = range(32768, 122881, 8192)
    }, tostring(var.cpu), []), var.memory)
    error_message = "memory is not a valid Fargate pairing for the chosen cpu (e.g. 256 CPU allows 512, 1024 or 2048 MiB)."
  }
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64. ARM64 (Graviton) is about 20% cheaper but cannot use Fargate Spot."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

################################################################################
# Cluster and capacity
################################################################################

variable "container_insights" {
  description = "Container Insights mode: enhanced, enabled or disabled."
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enhanced", "enabled", "disabled"], var.container_insights)
    error_message = "container_insights must be enhanced, enabled or disabled."
  }
}

variable "fargate_weight" {
  description = "Relative share of tasks placed on on-demand FARGATE."
  type        = number
  default     = 1

  validation {
    condition     = var.fargate_weight >= 0 && var.fargate_weight <= 1000
    error_message = "fargate_weight must be between 0 and 1000."
  }
}

variable "fargate_base" {
  description = "Tasks always placed on on-demand FARGATE before weights apply, so Spot interruptions never take the service to zero."
  type        = number
  default     = 1

  validation {
    condition     = var.fargate_base >= 0 && var.fargate_base <= 100000
    error_message = "fargate_base must be between 0 and 100000."
  }
}

variable "fargate_spot_weight" {
  description = "Relative share of tasks placed on FARGATE_SPOT (up to ~70% cheaper, can be interrupted with 2 minutes notice)."
  type        = number
  default     = 0

  validation {
    condition     = var.fargate_spot_weight >= 0 && var.fargate_spot_weight <= 1000
    error_message = "fargate_spot_weight must be between 0 and 1000."
  }

  validation {
    condition     = var.fargate_spot_weight == 0 || var.cpu_architecture == "X86_64"
    error_message = "Fargate Spot is not available for ARM64 tasks; set fargate_spot_weight to 0."
  }

  validation {
    condition     = var.fargate_weight + var.fargate_spot_weight > 0
    error_message = "At least one of fargate_weight or fargate_spot_weight must be greater than 0."
  }
}

################################################################################
# Service and deployment
################################################################################

variable "desired_count" {
  description = "Initial number of tasks. Auto scaling takes over afterwards when enabled."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count cannot be negative."
  }
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS ignores ALB health checks after a task starts, covering slow application boot."
  type        = number
  default     = 60

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 2147483647
    error_message = "health_check_grace_period_seconds must be a non-negative integer."
  }
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower bound of running tasks during a deployment, as a percentage of desired_count."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Upper bound of running tasks during a deployment, as a percentage of desired_count."
  type        = number
  default     = 200
}

variable "enable_execute_command" {
  description = "Allow `aws ecs execute-command` into running tasks. Sessions are KMS-encrypted and logged."
  type        = bool
  default     = false
}

################################################################################
# Auto scaling
################################################################################

variable "enable_autoscaling" {
  description = "Create Application Auto Scaling target-tracking policies on CPU and ALB requests per target."
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks."
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks; also the cost ceiling."
  type        = number
  default     = 6

  validation {
    condition     = var.autoscaling_max_capacity >= var.autoscaling_min_capacity
    error_message = "autoscaling_max_capacity must be greater than or equal to autoscaling_min_capacity."
  }
}

variable "autoscaling_cpu_target" {
  description = "Target average CPU utilisation (%) for the CPU policy."
  type        = number
  default     = 60

  validation {
    condition     = var.autoscaling_cpu_target > 0 && var.autoscaling_cpu_target <= 100
    error_message = "autoscaling_cpu_target must be between 1 and 100."
  }
}

variable "autoscaling_requests_per_target" {
  description = "Target ALB requests per task per minute for the request-count policy."
  type        = number
  default     = 1000

  validation {
    condition     = var.autoscaling_requests_per_target > 0
    error_message = "autoscaling_requests_per_target must be positive."
  }
}

################################################################################
# Alarms
################################################################################

variable "enable_alarms" {
  description = "Create CloudWatch alarms for target 5xx, unhealthy hosts and high CPU."
  type        = bool
  default     = true
}

variable "create_alarm_topic" {
  description = "Create a KMS-encrypted SNS topic and wire every alarm to it. Subscribe to it after apply."
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "Extra ARNs (for example an existing SNS topic) notified on alarm and OK transitions."
  type        = list(string)
  default     = []
}

variable "alarm_5xx_threshold" {
  description = "Target 5xx responses per minute that count as a breach."
  type        = number
  default     = 10
}

variable "alarm_cpu_threshold" {
  description = "Average service CPU (%) that counts as a breach."
  type        = number
  default     = 85
}

################################################################################
# Storage, encryption and logging
################################################################################

variable "ecr_keep_last_images" {
  description = "Number of images the ECR lifecycle policy keeps; older ones are expired."
  type        = number
  default     = 20

  validation {
    condition     = var.ecr_keep_last_images >= 1
    error_message = "ecr_keep_last_images must be at least 1."
  }
}

variable "ecr_force_delete" {
  description = "Allow destroying the ECR repository while it still holds images. Demo convenience only."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention for application and ECS Exec logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value CloudWatch Logs accepts (1, 3, 5, 7, 14, 30, 60, 90, ... 3653)."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the service KMS key is deleted after destroy."
  type        = number
  default     = 7

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "tags" {
  description = "Tags merged onto every resource."
  type        = map(string)
  default     = {}
}
