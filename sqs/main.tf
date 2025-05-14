resource "aws_sqs_queue" "my_queue" {
  name                       = "my-sqs-queue"
 
}
output "sqs_url" {
  value = aws_sqs_queue.my_queue.url
}