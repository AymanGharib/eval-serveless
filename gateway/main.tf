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
  //uri                     = aws_lambda_function.audio_handler.invoke_arn
  uri = var.audio_handler_invoke_arn
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
 // function_name = aws_lambda_function.audio_handler.function_name
 function_name = var.first_function_name
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
