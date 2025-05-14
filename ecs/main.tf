
resource "aws_ecs_cluster" "whisper_cluster" {
  name = "whisper_cluster"
}
resource "random_id" "id" {
  byte_length = 8
}

resource "aws_ecs_task_definition" "whisper_task" {
 
  family                   = "whisper-task-${random_id.id.hex}"
 // task_role_arn = "aws_iam_role.whisper_task_role.arn"  
task_role_arn =   var.whisper_task_role_arn
  
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  //execution_role_arn       =" aws_iam_role.whisper_task_execution_role.arn"
  execution_role_arn       = var.whisper_task_execution_role_arn

container_definitions = jsonencode([
  {
    name      = "whisper"
    image     = var.image
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
       // value = aws_s3_bucket.output-bucket.bucket
       value = var.output_bucket
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




