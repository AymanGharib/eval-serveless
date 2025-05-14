



output "audio_api_execution_arn" {
  value = aws_api_gateway_rest_api.audio_api.execution_arn

}



output "gateway_url" {

  value = "https://${aws_api_gateway_rest_api.audio_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.dev_stage.stage_name}"
}

variable "region" {
  default = "us-east-1"
}