output "repository_arn" {
  description = "Full ARN of the repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the repository"
  value       = aws_ecr_repository.this.name
}

output "repository_url" {
  description = "URL of the repository (in the form aws_account_id.dkr.ecr.region.amazonaws.com/repositoryName)"
  value       = aws_ecr_repository.this.repository_url
}

output "registry_id" {
  description = "Registry ID where the repository was created"
  value       = aws_ecr_repository.this.registry_id
}
