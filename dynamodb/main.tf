resource "aws_dynamodb_table" "reading_table" {
  name         = "ReadingEvaluation"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
