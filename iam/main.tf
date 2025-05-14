resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-audio-upload-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
     /*  Resource = ["${aws_s3_bucket.audio_bucket.arn}/*" ,  
          
        "${aws_s3_bucket.output-bucket.arn}/*"
        
        ]  */

        Resource = [
          "${var.first_bucket_arn}/*",
          "${var.first_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "transcribe:StartTranscriptionJob"
        ],
        Resource = "*"
      },
        {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ],
        Resource = "arn:aws:sqs:us-east-1:216874796625:Myqueue"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:*"
        ],
        Resource = "${var.dynamodb_table_arn}"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
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
      /*  Resource  = ["${aws_s3_bucket.output-bucket.arn}/*" ,  "${aws_s3_bucket.output-bucket.arn}" , 
                    "${aws_s3_bucket.audio_bucket.arn}/*" ,  "${aws_s3_bucket.audio_bucket.arn}" ],  */
 Resource  = [  "${var.first_bucket_arn}/*",
          "${var.first_bucket_arn}/*" , 
                      "${var.second_bucket_arn}/*",
          "${var.second_bucket_arn}/*" ]

        
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "whisper_task_attach_policy" {
  role       = aws_iam_role.whisper_task_role.name
  policy_arn = aws_iam_policy.whisper_task_policy.arn
}
