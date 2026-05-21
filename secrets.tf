# ─────────────────────────────────────────────────────────────────────────────
# Secrets Manager
#
# Stores all sensitive config in one encrypted secret.
# Your app reads this at startup instead of relying on plaintext env vars.
#
# App-side usage (after this commit):
#   import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager"
#   const client = new SecretsManagerClient({ region: process.env.AWS_REGION })
#   const { SecretString } = await client.send(
#     new GetSecretValueCommand({ SecretId: process.env.SECRET_ARN })
#   )
#   const secrets = JSON.parse(SecretString)
#
# After confirming the app reads secrets correctly, remove the plaintext
# values from elastic_beanstalk.tf env var settings.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "finpay" {
  name        = "${var.app_name}/${var.environment}/app-secrets"
  description = "FinPay API — JWT, DB credentials, Redis tokens"

  # 7-day recovery window: if you accidentally delete this, you have 7 days to restore
  # Set to 0 for immediate deletion during dev (not recommended for prod)
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "finpay" {
  secret_id = aws_secretsmanager_secret.finpay.id

  # All secrets in one JSON object — one API call to get everything at startup
  secret_string = jsonencode({
    JWT_SECRET               = var.jwt_secret
    JWT_EXPIRES_IN           = var.jwt_expires_in
    DATABASE_URL             = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.finpay.endpoint}/${var.db_name}?sslmode=require"
    UPSTASH_REDIS_REST_URL   = var.upstash_redis_rest_url
    UPSTASH_REDIS_REST_TOKEN = var.upstash_redis_rest_token
  })

  # Prevent Terraform from showing secret values in plan output
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# IAM policy — minimum permissions to read this one secret only
resource "aws_iam_policy" "secrets_read" {
  name        = "${var.app_name}-secrets-read"
  description = "Allow FinPay EB instances to read app secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadAppSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Scoped to this one secret only — not all secrets in the account
        Resource = aws_secretsmanager_secret.finpay.arn
      }
    ]
  })
}

# Attach to the EB instance role so EC2 instances can call Secrets Manager
# aws_iam_role.eb_instance is defined in your existing iam.tf
resource "aws_iam_role_policy_attachment" "eb_secrets" {
  role       = aws_iam_role.eb_instance.name
  policy_arn = aws_iam_policy.secrets_read.arn
}

output "secret_arn" {
  description = "Pass this as SECRET_ARN env var to EB so the app knows what to fetch"
  value       = aws_secretsmanager_secret.finpay.arn
}

output "secret_name" {
  description = "Secret name for AWS CLI testing: aws secretsmanager get-secret-value --secret-id <this>"
  value       = aws_secretsmanager_secret.finpay.name
}
