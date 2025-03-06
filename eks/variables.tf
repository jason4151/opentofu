# eks/variables.tf

variable "enable_public_endpoint" {
  description = "Enable public access to the EKS cluster endpoint (set to true for external access)"
  type        = bool
  default     = false # Private-only by default for security and cost
}

variable "public_endpoint_cidr" {
  description = "CIDR block allowed to access the EKS public endpoint"
  type        = string
  default     = "0.0.0.0/0" # Open to all by default; override with my current home IP during apply
}

variable "instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.micro" # Smaller instance for lab
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1 # Default to 1, no CLI override needed
}

variable "node_max_size" {
  description = "Maximum number of worker nodes for scaling"
  type        = number
  default     = 3 # Allow scaling up to 3 for HA testing
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 0 # Allow scaling to 0 when idle
}