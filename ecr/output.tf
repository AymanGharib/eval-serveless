output "ecr_repo_url" {
  value = aws_ecr_repository.whisper-repo.repository_url
}