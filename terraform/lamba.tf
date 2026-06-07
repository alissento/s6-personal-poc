resource "aws_iam_role" "lambda_exec_role" {
  name = "incident_response_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ec2_policy" {
  name = "lambda_ec2_policy"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstanceAttribute",
          "ec2:DescribeInstances",
          "ec2:CreateNetworkAclEntry",
          "ec2:ReplaceNetworkAclEntry",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifySecurityGroupRules"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "isolate_ec2_zip" {
  type        = "zip"
  output_path = "${path.module}/isolate_ec2.zip"
  source_file = "${path.module}/../lambdas/isolate_ec2.py"
}

resource "aws_lambda_function" "isolate_ec2" {
  function_name    = "isolate_ec2_instance"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "isolate_ec2.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.isolate_ec2_zip.output_path
  source_code_hash = data.archive_file.isolate_ec2_zip.output_base64sha256
}

data "archive_file" "add_ip_to_nacl_zip" {
  type        = "zip"
  output_path = "${path.module}/add_ip_to_nacl.zip"
  source_file = "${path.module}/../lambdas/add_ip_to_nacl.py"
}

resource "aws_lambda_function" "add_ip_to_nacl" {
  function_name    = "add_ip_to_nacl"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "add_ip_to_nacl.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.add_ip_to_nacl_zip.output_path
  source_code_hash = data.archive_file.add_ip_to_nacl_zip.output_base64sha256
}
