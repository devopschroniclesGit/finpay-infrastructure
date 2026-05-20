# ── Outputs ───────────────────────────────────────────────────────────────────
# These print after terraform apply completes

output "ecr_repository_url" {
  description = "ECR repository URI — used in Dockerfile pushes"
  value       = aws_ecr_repository.finpay.repository_url
}

output "eb_environment_url" {
  description = "Elastic Beanstalk app URL"
  value       = "http://${aws_elastic_beanstalk_environment.finpay_production.cname}"
}

output "rds_endpoint" {
  description = "RDS instance endpoint — private, only reachable from EB"
  value       = aws_db_instance.finpay.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.finpay.port
}

output "pipeline_name" {
  description = "CodePipeline name"
  value       = aws_codepipeline.finpay.name
}

output "s3_artifacts_bucket" {
  description = "S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "database_url" {
  description = "Full DATABASE_URL connection string"
  value       = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.finpay.address}:5432/${var.db_name}"
  sensitive   = true
}

output "health_check_url" {
  description = "API health check endpoint"
  value       = "http://${aws_elastic_beanstalk_environment.finpay_production.cname}/api/v1/health"
}

output "swagger_url" {
  description = "Swagger API documentation"
  value       = "http://${aws_elastic_beanstalk_environment.finpay_production.cname}/api/docs"
}
