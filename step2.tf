
resource "aws_s3_bucket" "output-bucket" {
  bucket = "transcribe-output-bucket-12344556"
}

resource "aws_s3_bucket_versioning" "output-bucket_versioning" {
  bucket = aws_s3_bucket.output-bucket.id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_cors_configuration" "output-bucket_bucket_cors" {
  bucket = aws_s3_bucket.output-bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "output_bucket_policy" {
  bucket = aws_s3_bucket.output-bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.output-bucket.arn}/*",
        
      },
      {
        Effect    = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.output-bucket.arn}/*",
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "${aws_api_gateway_rest_api.audio_api.execution_arn}/*"
          }
        }
      }
    ]
  })
    depends_on = [aws_s3_bucket_public_access_block.output-bucket_public_access_block]
}

resource "aws_s3_bucket_public_access_block" "output-bucket_public_access_block" {
  bucket = aws_s3_bucket.output-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


resource "aws_s3_bucket_notification" "s3_to_second_lambda" {
  bucket = aws_s3_bucket.output-bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.second_lambda.arn
    events              = ["s3:ObjectCreated:*" ]
filter_prefix = ""
    filter_suffix = ""
    
  }


  

 depends_on = [aws_lambda_permission.allow_second_s3]
} 




// lambda

resource "aws_lambda_function" "second_lambda" {
  function_name = "putaudio-todynamo"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "puttodynamo.lambda_handler"
  runtime       = "python3.9"
  architectures = [ "x86_64" ]
 filename         = "${path.module}/puttodynamo.zip"  # This makes it relative to the Terraform module
  source_code_hash = filebase64sha256("${path.module}/puttodynamo.zip")
environment {
  variables = {
    DDB_TABLE = aws_dynamodb_table.reading_table.name
  }
}

}



resource "aws_lambda_permission" "allow_second_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.second_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.output-bucket.arn
}





// dynamodb

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.second_lambda.function_name}"
  retention_in_days = 7
}