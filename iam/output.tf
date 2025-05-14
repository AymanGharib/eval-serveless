output "whisper_task_role_arn" {
  value = aws_iam_role.whisper_task_role.arn
}

output "whisper_task_execution_role_arn" {
  value = aws_iam_role.whisper_task_execution_role.arn
}

output "lambda_exec_role_arn" {



  value =  aws_iam_role.lambda_exec_role.arn
}


