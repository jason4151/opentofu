# eks/variables.tf

variable "public_endpoint_cidr" {
  description = "CIDR allowed to reach the EKS public API. Override with your current IP when you can; 0.0.0.0/0 keeps a lab usable from anywhere."
  type        = string
  default     = "0.0.0.0/0"
}
