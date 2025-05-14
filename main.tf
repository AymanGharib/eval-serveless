// dynamo
module "dynamo" {
  source = "./dynamodb"

}

// ecr 
module "ecr" {
  source = "./ecr"

}


// ecs 
module "ecs" {
  source = "./ecs"
  whisper_task_role_arn = module.iam.whisper_task_role_arn
  whisper_task_execution_role_arn = module.iam.whisper_task_execution_role_arn
  output_bucket = module.s3.output_bucket
    image = var.image

}

// gateway

module "gateway" {
  source = "./gateway"
  first_function_name  = module.lambda.first_function_name
  audio_handler_invoke_arn = module.lambda.audio_handler_invoke_arn

}

// iam 

module "iam" {
  source = "./iam"
  first_bucket_arn = module.s3.audio_bucket_arn 
  second_bucket_arn = module.s3.output_bucket_arn
  dynamodb_table_arn =  module.dynamo.dynamodb_table_arn
  
}

// lambda

module "lambda" {
  source = "./lambda"
 first_lambda_exec_role_arn = module.iam.lambda_exec_role_arn
  audio_bucket_name = module.s3.audio_bucket
  ddb_table_name = module.dynamo.dynamodb_table_name
  
  output_bucket_arn = module.s3.output_bucket_arn






  second_lambda_exec_role_arn = module.iam.lambda_exec_role_arn
}

// s3 

module "s3" {
  source = "./s3"
audio_api_execution_arn = module.gateway.audio_api_execution_arn
second_lambda_arn = module.lambda.secpond_lambda_arn
}

//sqs


module "sqs" {
  source = "./sqs"
  
}