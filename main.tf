
# S3 bucket for audio
resource "aws_s3_bucket" "audio_bucket" {
  bucket = "student-audio-bucket-demo"
}




resource "aws_s3_bucket_public_access_block" "disable_block_public_policy" {
  bucket = aws_s3_bucket.audio_bucket.id

  block_public_acls       = true
  block_public_policy     = false  # <-- This is the key fix
  ignore_public_acls      = true
  restrict_public_buckets = true
}










# DynamoDB table
resource "aws_dynamodb_table" "reading_table" {
  name         = "ReadingEvaluation"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# IAM Role for Lambda
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
        Resource = ["${aws_s3_bucket.audio_bucket.arn}/*" ,  
          
        "${aws_s3_bucket.output-bucket.arn}/*"
        
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
        Resource = "${aws_dynamodb_table.reading_table.arn}"
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

# Lambda Function
resource "aws_lambda_function" "audio_handler" {
  function_name = "uploadAudioHandler"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"

  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      AUDIO_BUCKET = aws_s3_bucket.audio_bucket.bucket
      DDB_TABLE    = aws_dynamodb_table.reading_table.name
      SQS_URL    = "https://sqs.us-east-1.amazonaws.com/216874796625/Myqueue"
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "audio_api" {
  name        = "AudioGateway"
  description = "Accepts audio + original text"
}

resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.audio_api.id
  parent_id   = aws_api_gateway_rest_api.audio_api.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.audio_api.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.audio_api.id
  resource_id             = aws_api_gateway_resource.upload.id
  http_method             = "POST"
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.audio_handler.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audio_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.audio_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.upload_lambda]
  rest_api_id = aws_api_gateway_rest_api.audio_api.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev_stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.audio_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}
