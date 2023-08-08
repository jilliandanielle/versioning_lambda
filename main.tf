provider "aws" {
}

# Source S3 bucket
resource "aws_s3_bucket" "source_bucket" {
  bucket_prefix = "jill-demo-src-"
  acl           = "private"
}

resource "aws_s3_bucket_versioning" "source_bucket_versioning" {
  bucket = aws_s3_bucket.source_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Destination S3 bucket
resource "aws_s3_bucket" "destination_bucket" {
  bucket_prefix = "jill-demo-dst-"
  acl           = "private"
}
resource "aws_s3_bucket_versioning" "destination_bucket_versioning" {
  bucket = aws_s3_bucket.destination_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.source_bucket.arn}/*",
        "${aws_s3_bucket.destination_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "arn:aws:logs:us-west-2:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:us-west-2:*:log-group:/aws/lambda/*"
      ]
    }
  ]
}
EOF
}

# Lambda function ZIP datasource
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "make_thumbnail.py"
  output_path = "make_thumbnail.zip"
}

# Lambda function resource
resource "aws_lambda_function" "thumbnail_lambda" {
  function_name = "ThumbnailCreator"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  filename         = data.archive_file.lambda_zip.output_path

  runtime = "python3.8"

  environment {
    variables = {
      SOURCE_BUCKET = aws_s3_bucket.source_bucket.bucket
      DEST_BUCKET   = aws_s3_bucket.destination_bucket.bucket
    }
  }
}

# S3 trigger for lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.source_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnail_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

# Permission for S3 event trigger
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source_bucket.arn
}
