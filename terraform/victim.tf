resource "aws_security_group" "victim_ec2_sg" {
  name        = "victim-ec2-sg"
  description = "Victim EC2 SG"
  vpc_id      = module.poc_pc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "victim-ec2-sg" }
}

resource "aws_iam_role" "victim_ec2_role" {
  name = "victim-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "victim_ec2_ssm_policy" {
  role       = aws_iam_role.victim_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "victim_ec2_profile" {
  name = "victim-ec2-profile"
  role = aws_iam_role.victim_ec2_role.name
}

resource "aws_instance" "victim_ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.nano"
  subnet_id                   = module.poc_pc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.victim_ec2_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.victim_ec2_profile.name

  depends_on = [module.poc_pc]

  tags = {
    Name = "victim-ubuntu-soar-test"
  }
}

resource "aws_security_group" "isolation_sg" {
  name        = "isolation-sg"
  description = "Isolation SG with no open ports"
  vpc_id      = module.poc_pc.vpc_id

  tags = { Name = "isolation-sg" }
}

