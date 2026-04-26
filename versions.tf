terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment after creating S3 bucket for state
  # backend "s3" {
  #   bucket = "finpay-terraform-state"
  #   key    = "finpay/infrastructure/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "finpay-api"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
