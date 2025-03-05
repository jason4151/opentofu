variable "vpc_cidr_block" {
  description = "The /22 CIDR block for the VPC (e.g., 10.33.0.0/22)"
  type        = string
  default     = "10.33.0.0/22"
}

variable "ha_nat_gateways" {
  description = "Set to true for a NAT Gateway per private subnet (HA), false for a single NAT Gateway (cost-saving)"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Set to true to enable the NAT Gateway, false to disable it (cost-saving)"
  type        = bool
  default     = false  # Disabled by default to save costs
}