# Provider versions inherited from root versions.tf

resource "aws_instance" "main" {
  ami = var.ami

  # Increased to t3.xlarge because of performance issues (and nasty bots) in the run up to the 2025 Federal election
  # TODO: Probably want to drop it back down once the flurry has passed
  instance_type = "t3.xlarge"
  ebs_optimized = true
  key_name      = var.deployer_key.key_name
  tags = {
    Name = "theyvoteforyou"
  }
  vpc_security_group_ids  = [var.security_group.id, var.security_group_service.id]
  disable_api_termination = true
  iam_instance_profile    = var.instance_profile.name
  # Setting the availability zone because it needs to be the same as the disk
  availability_zone = "ap-southeast-2a"
  # Because with 8 (the default) just having two versions of ruby with gems installed side-by-side
  # was enough to fill up the disk.
  root_block_device {
    volume_size = 16
  }
}

resource "aws_eip" "main" {
  domain = "vpc"
  tags = {
    Name = "theyvoteforyou"
  }
}

resource "aws_eip_association" "main" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main.id
}

resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.main.availability_zone

  size = 30
  type = "gp3"
  tags = {
    Name = "theyvoteforyou_data"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdi"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.main.id
}
