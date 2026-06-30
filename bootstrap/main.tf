# BOOTSTRAP — creates the Terraform state S3 bucket + the DynamoDB lock table
# used for state locking. Uses a LOCAL backend on purpose: it creates the remote
# backend, so it can't live in one.
# Run: cd bootstrap && terraform init && terraform apply.
# Credentials via AWS_* env vars.
terraform {
  required_version = ">= 1.5.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region_id" {
  type    = string
  default = "ap-southeast-5"
}

variable "state_bucket" {
  description = "Terraform state bucket name (must be globally unique)."
  type        = string
  default     = "nexus-aws-tfstate-primary"
}

variable "lock_table" {
  description = "DynamoDB table name for state locking."
  type        = string
  default     = "nexus-aws-tflock"
}

provider "aws" {
  region = var.region_id
}

# State bucket — versioned + encrypted, so the remote backend is managed by code.
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket
  # NOTE: add `lifecycle { prevent_destroy = true }` before using for real, to
  # guard against accidental teardown of the state backend.
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled" # protects against state corruption/rollback
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB lock table. The S3 backend uses a "LockID" string hash key.
resource "aws_dynamodb_table" "lock" {
  name         = var.lock_table
  billing_mode = "PAY_PER_REQUEST" # no reserved-capacity charge
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "lock_table" {
  value = aws_dynamodb_table.lock.name
}
