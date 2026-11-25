variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS requires at least two subnet IDs."
  }
}

variable "api_public_access_cidrs" {
  type = list(string)
}