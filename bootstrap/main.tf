# ─────────────────────────────────────────────────────────────────────────────
# BOOTSTRAP — run this ONCE before everything else
# This creates the S3 bucket and DynamoDB table that store Terraform state.
# It's intentionally separate so it doesn't manage its own state.
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply
#   cd ..
#   # Then uncomment the backend block in main.tf and run:
#   terraform init   ← this migrates local state into S3
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # Bootstrap always runs in eu-north-1 regardless of app region
  # The state bucket lives here permanently
  region = "eu-north-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "finpay-terraform-state-631185450332" # use your AWS account ID to guarantee uniqueness

  # Prevent accidental deletion of the bucket that holds your entire infrastructure state
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "finpay-terraform-state"
    ManagedBy = "terraform-bootstrap"
    Purpose   = "Stores terraform.tfstate for all finpay environments"
  }
}

# Keep every version of state — allows rollback if a bad apply corrupts state
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest — state files contain DB passwords, secrets
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State bucket must never be public — hard block
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
# When two people run terraform apply simultaneously, only one gets the lock.
# The second one waits until the first finishes, preventing state corruption.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "finpay-terraform-locks"
  billing_mode = "PAY_PER_REQUEST" # no idle cost — only charged when Terraform runs
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "finpay-terraform-locks"
    ManagedBy = "terraform-bootstrap"
  }
}

output "next_step" {
  value = <<-EOT
    Bootstrap complete. Now:
    1. Uncomment the backend block in ../main.tf
    2. Set bucket = "${aws_s3_bucket.terraform_state.bucket}"
    3. Run: cd .. && terraform init
       When prompted "Do you want to copy existing state?", type: yes
  EOT
}
