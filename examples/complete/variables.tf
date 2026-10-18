variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Short project name; combined with environment to form the resource prefix."
  type        = string
  default     = "webapp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.name))
    error_message = "name must be 2-15 chars, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the example VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "container_image" {
  description = "Image to run. Swap for <ecr_repository_url>:<git-sha> once you push the app/ image."
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:stable-alpine"
}

variable "container_port" {
  description = "Port the container listens on (80 for stock nginx, 8080 for the app/ image)."
  type        = number
  default     = 80
}

variable "container_user" {
  description = "UID the container runs as; null uses the image default (required for stock nginx)."
  type        = string
  default     = null
}

variable "readonly_root_filesystem" {
  description = "Read-only root filesystem. False for stock nginx; true for the app/ image."
  type        = bool
  default     = false
}

variable "writable_paths" {
  description = "Writable scratch paths when the root filesystem is read-only."
  type        = list(string)
  default     = []
}

variable "cpu" {
  description = "Task CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 512
}

variable "health_check_path" {
  description = "ALB health check path."
  type        = string
  default     = "/"
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave null for an HTTP-only demo."
  type        = string
  default     = null
}

variable "enable_waf" {
  description = "Attach the AWS managed WAF rule sets to the ALB."
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "ALB deletion protection. Off by default here so the demo destroys cleanly."
  type        = bool
  default     = false
}

variable "desired_count" {
  description = "Initial task count."
  type        = number
  default     = 2
}

variable "autoscaling_min_capacity" {
  description = "Minimum tasks."
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum tasks."
  type        = number
  default     = 4
}

variable "fargate_weight" {
  description = "Weight for on-demand Fargate."
  type        = number
  default     = 1
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot. Set to 3 for roughly 75% Spot after the on-demand base task."
  type        = number
  default     = 1
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging."
  type        = bool
  default     = false
}

variable "create_alarm_topic" {
  description = "Create an SNS topic for alarm notifications."
  type        = bool
  default     = true
}

variable "secrets" {
  description = "SSM / Secrets Manager ARNs to inject as environment variables."
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []
}
