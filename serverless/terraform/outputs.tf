output "receipt_bucket_name" {
  description = "Staging receipt bucket."
  value       = aws_s3_bucket.receipts.bucket
}

output "receipt_processor_function_name" {
  description = "Receipt processor Lambda."
  value       = aws_lambda_function.receipt_processor.function_name
}

output "notifier_function_name" {
  description = "Receipt notifier Lambda."
  value       = aws_lambda_function.notifier.function_name
}

output "payments_writer_user_name" {
  description = "Least-privilege IAM user used by staging kk-payments."
  value       = aws_iam_user.payments_writer.name
}

output "receipt_processor_log_group" {
  description = "Expected CloudWatch log group for processor."
  value       = "/aws/lambda/${aws_lambda_function.receipt_processor.function_name}"
}

output "notifier_log_group" {
  description = "Expected CloudWatch log group for notifier."
  value       = "/aws/lambda/${aws_lambda_function.notifier.function_name}"
}
