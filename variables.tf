variable "enable_routes" {
  description = "Enable Routes"
  type        = bool
  default     = true
}

variable "subnet_ids_nat_residency" {
  description = "Subnet IDs for NAT Residency"
  type        = list(any)
  default     = []
  validation {
    condition     = length(var.subnet_ids_nat_residency) > 0
    error_message = "NAT Residency Subnet IDs not Specified."
  }
}

variable "subnet_ids_nat_usage" {
  description = "Subnet IDs for NAT Usage"
  type        = list(any)
  default     = []
  validation {
    condition     = length(var.subnet_ids_nat_usage) > 0
    error_message = "NAT Usage Subnet IDs not Specified."
  }
}

variable "vpc_id" {
  description = "VPC: ID"
  type        = string
  default     = ""
  validation {
    condition     = var.vpc_id != ""
    error_message = "VPC ID not Specified."
  }
}
