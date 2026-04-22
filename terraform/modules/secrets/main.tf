resource "aws_kms_key" "secrets" {
  description             = "KMS key for ${var.project} ${var.environment} secrets"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = var.tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "redis" {
  name                    = "/${var.project}/${var.environment}/redis/password"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret" "mongodb" {
  name                    = "/${var.project}/${var.environment}/mongodb/credentials"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 0

  tags = var.tags
}
