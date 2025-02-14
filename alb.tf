# Write the terraform script to create load balancer
provider "aws" {
    region = "ap-south-1"
}

# vpc
resource "aws_vpc" "test-vpc" {
  cidr_block       = "15.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "test-vpc"
  }
}

# test-subnet-1
resource "aws_subnet" "test-subnet-1" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "15.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "test-subnet-1"
  }
}

# test-subnet-2
resource "aws_subnet" "test-subnet-2" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "15.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "test-subnet-2"
  }
}

# test-subnet-3
resource "aws_subnet" "test-subnet-3" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "15.0.3.0/24"
  availability_zone = "ap-south-1c"

  tags = {
    Name = "test-subnet-3"
  }
}

# test-igw
resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "test-igw"
  }
}

# test-RT
resource "aws_route_table" "test-RT" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-igw.id
  }

  tags = {
    Name = "test-RT"
  }
}

# subnet-route table association
resource "aws_route_table_association" "subnet-association-rt" {
  subnet_id      = aws_subnet.test-subnet-1.id
  route_table_id = aws_route_table.test-RT.id
}

# test-sg
resource "aws_security_group" "test-sg" {
  name        = "test-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.test-vpc.id}"

  ingress {
    description = "allow_https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow_http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow_SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test-sg"
  }
}

# ec2-instance
resource "aws_instance" "test-server" {
  count          = "3"
  ami            = "ami-00bb6a80f01f03502"
  instance_type  = "t2.micro"
  key_name       = "demo-key"
  subnet_id     =  aws_subnet.test-subnet-1.id
  vpc_security_group_ids = [aws_security_group.test-sg.id]
  associate_public_ip_address = true
  user_data = "${file("script.sh")}"
  tags = {
    Name = "test-server ${count.index}"
  }
}

resource "aws_lb" "makemytrip_alb" {
  name               = "makemytrip-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.test-sg.id]
  subnets           = [aws_subnet.test-subnet-1.id, aws_subnet.test-subnet-2.id, aws_subnet.test-subnet-3.id]
}

resource "aws_lb_target_group" "makemytrip_tg" {
  name     = "makemytrip-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.test-vpc.id
}

resource "aws_lb_target_group_attachment" "attach-ec2-tg" {
  count            = length(aws_instance.test-server)
  target_group_arn = aws_lb_target_group.makemytrip_tg.arn
  target_id        = aws_instance.test-server[count.index].id
  port            = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.makemytrip_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.makemytrip_tg.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.makemytrip_alb.dns_name
}
