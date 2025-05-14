output "output_bucket" {
  value = aws_s3_bucket.buckets[1].bucket
}


output "output_bucket_arn" {
  value = aws_s3_bucket.buckets[1].arn
}



output "audio_bucket_arn" {
  value = aws_s3_bucket.buckets[0].arn
}



output "audio_bucket" {
  value = aws_s3_bucket.buckets[0].bucket
}
