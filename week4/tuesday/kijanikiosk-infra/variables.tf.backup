variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = startswith(var.instance_type, "t")
    error_message = "Instance type must start with 't'."
  }
}

variable "environment" {
  description = "Deployment environment"

  type = string

  default = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "ssh_key_name" {
  description = "EC2 key pair name"

  type = string
}
