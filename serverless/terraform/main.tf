data "aws_caller_identity" "current" {}

# ============================================================
# S3 RECEIPT BUCKET
# ============================================================

resource "aws_s3_bucket" "receipts" {
  bucket = var.receipt_bucket_name

  tags = {
    Name        = var.receipt_bucket_name
    Application = "KijaniKiosk"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "receipts" {
  bucket = aws_s3_bucket.receipts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "receipts" {
  bucket = aws_s3_bucket.receipts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "receipts" {
  bucket = aws_s3_bucket.receipts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================
# LAMBDA PACKAGING
# ============================================================

data "archive_file" "receipt_processor" {
  type = "zip"

  source_file = "${path.module}/../functions/receipt-processor/index.py"
  output_path = "${path.module}/.build/receipt-processor.zip"
}

data "archive_file" "notifier" {
  type = "zip"

  source_file = "${path.module}/../functions/notifier/index.py"
  output_path = "${path.module}/.build/notifier.zip"
}

# ============================================================
# RECEIPT PROCESSOR IAM ROLE
# ============================================================

resource "aws_iam_role" "receipt_processor" {
  name = "kk-receipt-processor-staging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Application = "KijaniKiosk"
    Environment = "staging"
  }
}

resource "aws_iam_role_policy_attachment" "receipt_processor_logs" {
  role = aws_iam_role.receipt_processor.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================
# NOTIFIER IAM ROLE
# ============================================================

resource "aws_iam_role" "notifier" {
  name = "kk-receipt-notifier-staging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Application = "KijaniKiosk"
    Environment = "staging"
  }
}

resource "aws_iam_role_policy_attachment" "notifier_logs" {
  role = aws_iam_role.notifier.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================
# NOTIFIER LAMBDA
# ============================================================

resource "aws_lambda_function" "notifier" {
  function_name = "kk-receipt-notifier-staging"

  filename         = data.archive_file.notifier.output_path
  source_code_hash = data.archive_file.notifier.output_base64sha256

  role    = aws_iam_role.notifier.arn
  handler = "index.handler"
  runtime = "python3.12"

  timeout     = 15
  memory_size = 128

  environment {
    variables = {
      RECEIPTS_BUCKET = aws_s3_bucket.receipts.bucket
      ENVIRONMENT     = "staging"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.notifier_logs
  ]

  tags = {
    Application = "KijaniKiosk"
    Environment = "staging"
    Component   = "receipt-notifier"
  }
}

# ============================================================
# RECEIPT PROCESSOR LAMBDA
# ============================================================

resource "aws_lambda_function" "receipt_processor" {
  function_name = "kk-receipt-processor-staging"

  filename         = data.archive_file.receipt_processor.output_path
  source_code_hash = data.archive_file.receipt_processor.output_base64sha256

  role    = aws_iam_role.receipt_processor.arn
  handler = "index.handler"
  runtime = "python3.12"

  timeout     = 15
  memory_size = 128

  environment {
    variables = {
      NOTIFIER_FUNCTION = aws_lambda_function.notifier.function_name
      RECEIPTS_BUCKET   = aws_s3_bucket.receipts.bucket
      ENVIRONMENT       = "staging"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.receipt_processor_logs
  ]

  tags = {
    Application = "KijaniKiosk"
    Environment = "staging"
    Component   = "receipt-processor"
  }
}

# ============================================================
# PROCESSOR PERMISSIONS
# ============================================================

resource "aws_iam_role_policy" "receipt_processor" {
  name = "kk-receipt-processor-staging-policy"
  role = aws_iam_role.receipt_processor.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadIncomingReceipts"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${aws_s3_bucket.receipts.arn}/incoming/*"
      },
      {
        Sid    = "WriteProcessedReceipts"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.receipts.arn}/processed/*"
      },
      {
        Sid    = "InvokeNotifier"
        Effect = "Allow"

        Action = [
          "lambda:InvokeFunction"
        ]

        Resource = aws_lambda_function.notifier.arn
      }
    ]
  })
}

# ============================================================
# NOTIFIER PERMISSIONS
# ============================================================

resource "aws_iam_role_policy" "notifier" {
  name = "kk-receipt-notifier-staging-policy"
  role = aws_iam_role.notifier.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "WriteNotifications"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.receipts.arn}/notifications/*"
      }
    ]
  })
}

# ============================================================
# ALLOW S3 TO INVOKE PROCESSOR
# ============================================================

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receipt_processor.function_name

  principal = "s3.amazonaws.com"

  source_arn     = aws_s3_bucket.receipts.arn
  source_account = data.aws_caller_identity.current.account_id
}

# ============================================================
# S3 -> RECEIPT PROCESSOR EVENT
#
# IMPORTANT:
# Only incoming/ triggers the processor.
#
# processed/ and notifications/ MUST NOT trigger this function,
# otherwise we would create an event loop.
# ============================================================

resource "aws_s3_bucket_notification" "receipt_created" {
  bucket = aws_s3_bucket.receipts.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.receipt_processor.arn

    events = [
      "s3:ObjectCreated:*"
    ]

    filter_prefix = "incoming/"
    filter_suffix = ".json"
  }

  depends_on = [
    aws_lambda_permission.allow_s3,
    aws_iam_role_policy.receipt_processor,
    aws_iam_role_policy.notifier
  ]
}

# ============================================================
# STAGING PAYMENT WRITER IAM USER
#
# Terraform deliberately does NOT create its access key.
# That prevents credentials from being stored in Terraform state.
# ============================================================

resource "aws_iam_user" "payments_writer" {
  name = "kk-payments-staging-receipt-writer"

  tags = {
    Application = "KijaniKiosk"
    Environment = "staging"
    Component   = "payments"
  }
}

resource "aws_iam_user_policy" "payments_writer" {
  name = "kk-payments-staging-receipt-writer-policy"
  user = aws_iam_user.payments_writer.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "WriteIncomingReceipts"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.receipts.arn}/incoming/*"
      }
    ]
  })
}
