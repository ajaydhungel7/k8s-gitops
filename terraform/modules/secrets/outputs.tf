output "kms_key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.secrets.arn
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.secrets.key_id
}

output "redis_secret_arn" {
  description = "Redis secret ARN"
  value       = aws_secretsmanager_secret.redis.arn
}

output "mongodb_secret_arn" {
  description = "MongoDB secret ARN"
  value       = aws_secretsmanager_secret.mongodb.arn
}
