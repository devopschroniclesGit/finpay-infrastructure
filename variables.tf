variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "finpay"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name"
  type        = string
  default     = "finpay-api"
}

variable "github_branch" {
  description = "GitHub branch to deploy from"
  type        = string
  default     = "main"
}

variable "github_token" {
  description = "GitHub personal access token for CodePipeline"
  type        = string
  sensitive   = true
}
