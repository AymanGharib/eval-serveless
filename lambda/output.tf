

output "first_function_name" {


    value = aws_lambda_function.audio_handler.function_name

 }




output "audio_handler_invoke_arn" {
  value =  aws_lambda_function.audio_handler.invoke_arn
}

output "secpond_lambda_arn" {
  value = aws_lambda_function.second_lambda.arn
  
}


