resource "aws_ecr_repository" "whisper-repo" {
 
  name                 = "whisper-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "whisper-repo"
    Environment = "dev"
  }
}


