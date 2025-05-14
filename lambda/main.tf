resource "aws_lambda_function" "audio_handler" {
  function_name = "uploadAudioHandler"
  //role          = aws_iam_role.lambda_exec_role.arn
  role = var.first_lambda_exec_role_arn
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"

  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
   //   AUDIO_BUCKET = aws_s3_bucket.audio_bucket.bucket
       // first bucket
        AUDIO_BUCKET = var.audio_bucket_name

    //  DDB_TABLE    = aws_dynamodb_table.reading_table.name
        DDB_TABLE    = var.ddb_table_name
      SQS_URL    = "https://sqs.us-east-1.amazonaws.com/216874796625/Myqueue"
    }
  }
}







resource "aws_lambda_function" "second_lambda" {
  function_name = "putaudio-todynamo"
 // role          = aws_iam_role.lambda_exec_role.arn
 role = var.second_lambda_exec_role_arn
  handler       = "puttodynamo.lambda_handler"
  runtime       = "python3.9"
  architectures = [ "x86_64" ]
 filename         = "${path.module}/puttodynamo.zip"  # This makes it relative to the Terraform module
  source_code_hash = filebase64sha256("${path.module}/puttodynamo.zip")
environment {
  variables = {
  //  DDB_TABLE = aws_dynamodb_table.reading_table.name
    DDB_TABLE = var.ddb_table_name
  }
}

}



resource "aws_lambda_permission" "allow_second_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.second_lambda.function_name
  principal     = "s3.amazonaws.com"
 // source_arn    = aws_s3_bucket.output-bucket.arn
 //  second bucket
    source_arn    = var.output_bucket_arn
}





// dynamodb

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.second_lambda.function_name}"
  retention_in_days = 7
}


