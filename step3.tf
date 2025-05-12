// ecr repo

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

output "ecr_repo_url" {
  value = aws_ecr_repository.whisper-repo.repository_url
}

// sqs queue
resource "aws_sqs_queue" "my_queue" {
  name                       = "my-sqs-queue"
  delay_seconds              = 0
  message_retention_seconds  = 345600   # Messages live up to 4 days
 // visibility_timeout_seconds = 300      # Message hidden for 5 minutes after being received
  //receive_wait_time_seconds  = 0        # No long polling
}
output "sqs_url" {
  value = aws_sqs_queue.my_queue.url
}
//ecs


resource "aws_ecs_cluster" "whisper_cluster" {
  name = "whisper_cluster"
}


resource "aws_ecs_task_definition" "whisper_task" {
 
  family                   = "whisper-task-${random_id.id.hex}"
  task_role_arn = aws_iam_role.whisper_task_role.arn

  
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.whisper_task_execution_role.arn

container_definitions = jsonencode([
  {
    name      = "whisper"
    image     = "216874796625.dkr.ecr.us-east-1.amazonaws.com/whisper-repo:latest"
    essential = true

   environment = [
      {
        name  = "AWS_REGION"
        value = "us-east-1"
      },
      {
        name  = "SQS_QUEUE_URL"
        value = "https://sqs.us-east-1.amazonaws.com/216874796625/Myqueue"
      },
      {
        name  = "OUTPUT_BUCKET"
        value = aws_s3_bucket.output-bucket.bucket
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/whisper"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }
    healthCheck = {
  command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
  interval    = 30
  timeout     = 5
  retries     = 3
  startPeriod = 60
}
  }
])

}

resource "aws_ecs_service" "whisper-service" {
  
  name            = "whisper-service"
  cluster         = aws_ecs_cluster.whisper_cluster.id
  launch_type     = "FARGATE"
  task_definition =  aws_ecs_task_definition.whisper_task.arn
  desired_count   = 1
    network_configuration {
        subnets          = ["subnet-0297563c2bf7bbc83", "subnet-0bd02c2ce6d7a3d7f"]
        assign_public_ip = true
    }




}







resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/whisper"
  retention_in_days = 7
}









resource "aws_iam_role" "whisper_task_execution_role" {
  name = "whisper_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.whisper_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}





resource "aws_iam_role" "whisper_task_role" {
  name = "whisper_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "random_id" "id" {
    byte_length = 8
  
}

resource "aws_iam_policy" "whisper_task_policy" {
  name = "whisper_task_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
         {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = "arn:aws:sqs:us-east-1:216874796625:Myqueue"
      },
          {
        Effect    = "Allow",
       
        Action    = "s3:*",
        Resource  = ["${aws_s3_bucket.output-bucket.arn}/*" ,  "${aws_s3_bucket.output-bucket.arn}" , 
                    "${aws_s3_bucket.audio_bucket.arn}/*" ,  "${aws_s3_bucket.audio_bucket.arn}" ],
        
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "whisper_task_attach_policy" {
  role       = aws_iam_role.whisper_task_role.name
  policy_arn = aws_iam_policy.whisper_task_policy.arn
}




























//iam
