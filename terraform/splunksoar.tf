resource "aws_instance" "splunk_soar_ec2" {
  ami                         = "ami-0771826ea69010c2f"
  instance_type               = "t3.xlarge"
  subnet_id                   = module.poc_pc.private_subnets[0]
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.splunk_soar_ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.splunk_soar_ec2.name

  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  depends_on = [module.poc_pc]

  tags = { Name = "splunk-soar-ec2" }
}

resource "aws_security_group" "splunk_soar_ec2_sg" {
  name        = "splunk-soar-ec2-sg"
  description = "Splunk SOAR EC2 security group"
  vpc_id      = module.poc_pc.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS (for Wazuh Webhooks/API)"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "splunk-soar-ec2-sg" }
}

resource "aws_iam_role" "splunk_soar_ec2" {
  name = "splunk-soar-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "splunk-soar-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "splunk_soar_ec2_ssm" {
  role       = aws_iam_role.splunk_soar_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "splunk_soar_lambda" {
  name = "splunk-soar-lambda-policy"
  role = aws_iam_role.splunk_soar_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "lambda:*"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "splunk_soar_ec2" {
  name = "splunk-soar-ec2-profile"
  role = aws_iam_role.splunk_soar_ec2.name

  tags = { Name = "splunk-soar-ec2-profile" }
}

output "splunk_soar_private_ip" {
  description = "Private IP of the Splunk SOAR EC2 instance"
  value       = aws_instance.splunk_soar_ec2.private_ip
}