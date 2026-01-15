# Provider versions inherited from root versions.tf

resource "aws_instance" "main" {
  ami = var.ami

  # Keeping this as small as we possibly can
  instance_type = "t3.nano"
  ebs_optimized = true
  key_name      = "deployer_key"
  tags = {
    Name = "au.proxy"
  }
  security_groups = [aws_security_group.main.name]

  # disable_api_termination = true
  iam_instance_profile = var.instance_profile.name
}

resource "aws_eip" "main" {
  domain = "vpc"
  tags = {
    Name = "au.proxy"
  }
}

resource "aws_eip_association" "main" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main.id
}

resource "aws_security_group" "main" {
  name        = "proxy"
  description = "standard security group for web proxies running on port 8888"

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 8888
    to_port          = 8888
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow pings from hosts on the internet
  ingress {
    protocol         = "icmp"
    from_port        = 8
    to_port          = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow everything going out
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
