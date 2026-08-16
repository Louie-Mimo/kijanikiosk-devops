variable "aws_region" {
  description = "AWS region for the staging receipt chain."
  type        = string
  default     = "eu-north-1"
}

variable "receipt_bucket_name" {
  description = "Staging receipt S3 bucket."
  type        = string
  default     = "kk-payments-receipts-staging"
}
