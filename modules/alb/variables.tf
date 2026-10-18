variable "name" {
  description = "Name prefix for the ALB, target group, security groups and log bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,22}[a-z0-9]$", var.name))
    error_message = "name must be 3-24 chars, lowercase letters, digits and hyphens (ALB names are capped at 32 chars including suffix)."
  }
}

variable "vpc_id" {
  description = "VPC to create the security groups and target group in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB (at least two AZs)."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An ALB needs subnets in at least two Availability Zones."
  }
}

variable "container_port" {
  description = "Port the container listens on; used for the target group and SG rules."
  type        = number
  default     = 80

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "allowed_cidrs" {
  description = "IPv4 CIDRs allowed to reach the ALB on 80/443. Defaults to the whole internet for a public site."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_cidrs) > 0 && alltrue([for c in var.allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "allowed_cidrs must contain at least one valid IPv4 CIDR."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN. When set, port 80 redirects to an HTTPS listener; when null, port 80 forwards directly (demo mode, no TLS)."
  type        = string
  default     = null

  validation {
    condition     = var.certificate_arn == null || can(regex("^arn:aws[a-z-]*:acm:[a-z0-9-]+:[0-9]{12}:certificate/.+$", var.certificate_arn))
    error_message = "certificate_arn must be null or a valid ACM certificate ARN."
  }
}

variable "ssl_policy" {
  description = "TLS negotiation policy for the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "health_check_path" {
  description = "HTTP path the target group polls for health."
  type        = string
  default     = "/"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must start with '/'."
  }
}

variable "health_check_matcher" {
  description = "HTTP status codes treated as healthy."
  type        = string
  default     = "200-399"
}

variable "deregistration_delay" {
  description = "Seconds to drain connections before a target is removed. Lower speeds up deploys."
  type        = number
  default     = 30
}

variable "idle_timeout" {
  description = "ALB idle connection timeout in seconds."
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Prevent the ALB being deleted by accident. Disable for throwaway demos so destroy works."
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Attach a WAFv2 web ACL with AWS managed rule groups. Adds roughly 5-7 USD/month plus per-request charges."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Days to keep ALB access logs in S3 before expiry."
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 1
    error_message = "log_retention_days must be at least 1."
  }
}

variable "log_bucket_force_destroy" {
  description = "Allow destroying the log bucket while it still contains objects. Useful for demos only."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags merged onto every resource."
  type        = map(string)
  default     = {}
}
