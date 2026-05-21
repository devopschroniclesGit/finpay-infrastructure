terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend indentation must be exactly 2 spaces inside terraform {}
  # No leading space before "backend"
  backend "s3" {
    bucket         = "finpay-terraform-state"
    key            = "finpay/production/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "finpay-terraform-locks"
  }
}

# ── Default provider ──────────────────────────────────────────────────────────
# Deploys everything to whatever region is set in terraform.tfvars
# This is what all your existing resources use (EB, RDS, ECR, CodePipeline)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "finpay"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "devopschronicles"
    }
  }
}

# ── us-east-1 alias ───────────────────────────────────────────────────────────
# ONLY used for the CloudFront ACM certificate
# AWS hard requirement: CloudFront certs must live in us-east-1 regardless of
# where your app is deployed
# Only acm.tf uses this via: provider = aws.us_east_1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "finpay"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "devopschronicles"
    }
  }
}

# ── Data sources ──────────────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
