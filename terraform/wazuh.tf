resource "aws_security_group" "wazuh_ec2" {
  name        = "wazuh-ec2-sg"
  description = "Wazuh EC2 SG"
  vpc_id      = module.poc_pc.vpc_id

  ingress {
    description = "Wazuh agent events"
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = [module.poc_pc.vpc_cidr_block]
  }
  ingress {
    description = "Wazuh agent enrollment"
    from_port   = 1515
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = [module.poc_pc.vpc_cidr_block]
  }

  ingress {
    description = "Wazuh agent events"
    from_port   = 1514
    to_port     = 1514
    protocol    = "tcp"
    cidr_blocks = [module.poc_pc.vpc_cidr_block]
  }

  ingress {
    description = "Wazuh agent enrollment"
    from_port   = 1515
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = [module.poc_pc.vpc_cidr_block]
  }

  ingress {
    description = "Wazuh API"
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = [module.poc_pc.vpc_cidr_block]
  }

  ingress {
    description = "OpenSearch HTTP"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [module.poc_pc.vpc_cidr_block]
  }

  ingress {
    description = "Dashboard HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.poc_pc.vpc_cidr_block]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "wazuh-ec2-sg" }
}

resource "aws_iam_role" "wazuh_ec2" {
  name = "wazuh-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "wazuh-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "wazuh_ec2_ssm" {
  role       = aws_iam_role.wazuh_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "wazuh_ec2" {
  name = "wazuh-ec2-profile"
  role = aws_iam_role.wazuh_ec2.name

  tags = { Name = "wazuh-ec2-profile" }
}

resource "aws_instance" "wazuh" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.large"
  subnet_id                   = module.poc_pc.private_subnets[0]
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.wazuh_ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.wazuh_ec2.name

  root_block_device {
    volume_size           = 60
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  depends_on = [module.poc_pc]

  tags = { Name = "wazuh-ec2" }
}

output "wazuh_private_ip" {
  description = "Private IP of the Wazuh all-in-one EC2 instance"
  value       = aws_instance.wazuh.private_ip
}
