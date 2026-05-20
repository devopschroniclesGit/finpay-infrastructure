variable "aws_region" {
  description = "AWS region to deploy into — change this to move regions"
  type        = string
  default     = "eu-north-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Application name — used as prefix for all resources"
  type        = string
  default     = "finpay"
}

# ── Database ────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "finpay_db"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "finpay_user"
}

variable "db_password" {
  description = "PostgreSQL master password — set via TF_VAR_db_password env var, never hardcode"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "RDS storage in GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

# ── Elastic Beanstalk ────────────────────────────────────────────────────────

variable "eb_instance_type" {
  description = "EC2 instance type for Elastic Beanstalk"
  type        = string
  default     = "t3.micro"
}

variable "eb_solution_stack" {
  description = "EB solution stack — Docker on Amazon Linux 2023"
  type        = string
  default     = "64bit Amazon Linux 2023 v4.5.1 running Docker"
}

# ── Application secrets ──────────────────────────────────────────────────────
# These are passed as environment variables to Elastic Beanstalk
# Set via terraform.tfvars or environment variables (TF_VAR_*)
# NEVER commit actual values to git

variable "jwt_secret" {
  description = "JWT signing secret — minimum 32 characters"
  type        = string
  sensitive   = true
}

variable "jwt_expires_in" {
  description = "JWT token expiry"
  type        = string
  default     = "7d"
}

variable "upstash_redis_rest_url" {
  description = "Upstash Redis REST URL"
  type        = string
  sensitive   = true
}

variable "upstash_redis_rest_token" {
  description = "Upstash Redis REST token"
  type        = string
  sensitive   = true
}

variable "rate_limit_window_ms" {
  description = "Rate limiting window in milliseconds"
  type        = string
  default     = "900000"
}

variable "rate_limit_max_requests" {
  description = "Maximum requests per window"
  type        = string
  default     = "100"
}

# ── GitHub ────────────────────────────────────────────────────────────────────

variable "github_repo" {
  description = "GitHub repository — format: owner/repo"
  type        = string
  default     = "devopschroniclesGit/finpay-api"
}

variable "github_branch" {
  description = "GitHub branch to deploy"
  type        = string
  default     = "main"
}

variable "github_connection_arn" {
  description = "AWS CodeConnections ARN for GitHub — create manually in console first"
  type        = string
  # Get this from: AWS Console → CodePipeline → Settings → Connections
}
