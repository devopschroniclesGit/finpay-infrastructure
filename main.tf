terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — store in S3 so team can share state
  # Uncomment after creating the S3 bucket manually
  # backend "s3" {
  #   bucket  = "finpay-terraform-state"
  #   key     = "finpay/production/terraform.tfstate"
  #   region  = "eu-north-1"
  #   encrypt = true
  # }
}

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

# Data sources
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
