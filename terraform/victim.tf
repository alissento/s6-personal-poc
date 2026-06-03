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
}

resource "aws_instance" "victim_ec2" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.nano"
  subnet_id                   = module.poc_pc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.victim_ec2_sg.id]
  associate_public_ip_address = true

  depends_on = [module.poc_pc]

  tags = {
    Name = "victim-ubuntu-soar-test"
  }
}
