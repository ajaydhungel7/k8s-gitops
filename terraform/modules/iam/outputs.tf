output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

output "jenkins_role_arn" {
  description = "IAM role ARN for Jenkins"
  value       = aws_iam_role.jenkins.arn
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for ALB Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler.arn
}
