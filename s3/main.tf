
# S3 bucket for audio
resource "aws_s3_bucket" "buckets" {
count = length(var.bucket_names)
  bucket = var.bucket_names[count.index]
 


}



variable "bucket_names" {
  type = list(string)
  default = [ "student-audio-bucket-demo" , "transcribe-output-bucket-12344556"]
}

resource "aws_s3_bucket_public_access_block" "disable_block_public_policy" {
  count = length(var.bucket_names)
  bucket = aws_s3_bucket.buckets[count.index].id

  block_public_acls       = true
  block_public_policy     = false  # <-- This is the key fix
  ignore_public_acls      = true
  restrict_public_buckets = true
}




resource "aws_s3_bucket_versioning" "output-bucket_versioning" {
  bucket =  aws_s3_bucket.buckets[1].id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_cors_configuration" "output-bucket_bucket_cors" {
  bucket =  aws_s3_bucket.buckets[1].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "output_bucket_policy" {
  bucket =  aws_s3_bucket.buckets[1].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[1].arn}/*",
        
      },
      {
        Effect    = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.buckets[1].arn}/*",
        Condition = {
          StringEquals = {
          //  "aws:SourceArn" = "${aws_api_gateway_rest_api.audio_api.execution_arn}/*"
            "aws:SourceArn" = "${var.audio_api_execution_arn}/*"
          }
        }
      }
    ]
  })
    depends_on = [aws_s3_bucket_public_access_block.disable_block_public_policy]
}



// only for bucket2
resource "aws_s3_bucket_notification" "s3_to_second_lambda" {
  bucket = aws_s3_bucket.buckets[1].id
  lambda_function {
  //  lambda_function_arn = aws_lambda_function.second_lambda.arn
  lambda_function_arn = var.second_lambda_arn
    events              = ["s3:ObjectCreated:*" ]
filter_prefix = ""
    filter_suffix = ""
    
  }


  // add it in the root main.tf file

 //  depends_on = [aws_lambda_permission.allow_second_s3]
} 


