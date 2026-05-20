# ── RDS PostgreSQL ────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "finpay" {
  name        = "${var.app_name}-db-subnet-group"
  description = "FinPay RDS subnet group"
  subnet_ids  = data.aws_subnets.default.ids
}

resource "aws_db_instance" "finpay" {
  identifier = "${var.app_name}-postgres"

  # Engine
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Storage
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.finpay.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # private — only reachable from EB

  # Backups
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Protection
  deletion_protection = false # set to true for real production
  skip_final_snapshot = true  # set to false for real production

  # Performance Insights (free for t3.micro)
  performance_insights_enabled = false

  # Parameter group — use defaults
  parameter_group_name = "default.postgres15"
}
