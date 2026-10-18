variable "name" {
  description = "Name prefix applied to every network resource."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3-32 chars, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. A /16 to /20 leaves room for the /24 subnet split."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a prefix between /16 and /20."
  }
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix for each subnet (8 turns a /16 into /24s)."
  type        = number
  default     = 8

  validation {
    condition     = var.subnet_newbits >= 4 && var.subnet_newbits <= 8
    error_message = "subnet_newbits must be between 4 and 8."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to span. Two is the minimum for an ALB."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "tags" {
  description = "Tags merged onto every resource."
  type        = map(string)
  default     = {}
}
