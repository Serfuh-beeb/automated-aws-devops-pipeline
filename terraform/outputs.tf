output "alb_dns" {
  description = "ALB DNS name — the app URL"
  value       = aws_lb.main.dns_name
}

output "ecr_repo_url" {
  description = "ECR repository URL for Docker push"
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "ecs_cluster" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}


output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_lb.main.dns_name}:3000"
}

output "prometheus_ecr" {
  description = "Prometheus ECR repo URL"
  value       = aws_ecr_repository.prometheus.repository_url
}

output "grafana_ecr" {
  description = "Grafana ECR repo URL"
  value       = aws_ecr_repository.grafana.repository_url
}
