# Write the terraform script for setup autoscaling
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# create vpc
resource "aws_vpc" "test-vpc" {
  cidr_block       = "15.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "test-vpc"
  }
}

# create test-subnet-1
resource "aws_subnet" "test-subnet-1" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "15.0.1.0/24"
  availability_zone = "ap-south-1a"
  
  tags = {
    Name = "test-subnet-1"
  }
}

# create test-subnet-2
resource "aws_subnet" "test-subnet-2" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "15.0.2.0/24"
  availability_zone = "ap-south-1b"
 
  tags = {
    Name = "test-subnet-2"
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

# create asg security group
resource "aws_security_group" "asg_sg" {
  vpc_id = aws_vpc.test-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from internet
  }
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from internet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



# create alb security group
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.test-vpc.id

  ingress {
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

# create template
resource "aws_launch_template" "test_template" {
  name_prefix   = "app-launch-template"
  image_id      = "ami-00bb6a80f01f03502"  # Replace with a valid AMI ID
  key_name      = "demo-key"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.asg_sg.id]
  }

  user_data = base64encode(<<-EOF
              #! /bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "WELCOME TO TEKS ACADEMY" | sudo tee /var/www/html/index.html
              EOF
  )
}

# adjust autoscaling group capacity
resource "aws_autoscaling_group" "teksit-asg" {
  desired_capacity    = 3
  min_size            = 1
  max_size            = 5
  vpc_zone_identifier = [aws_subnet.test-subnet-1.id, aws_subnet.test-subnet-2.id]

  launch_template {
    id      = aws_launch_template.test_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.teksit-tg.arn]
}

# create load balancer
resource "aws_lb" "teksit-alb" {
  name               = "teksit-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.test-subnet-1.id, aws_subnet.test-subnet-2.id]
}

# create target group
resource "aws_lb_target_group" "teksit-tg" {
  name     = "teksit-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.test-vpc.id
}

# create listner
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.teksit-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.teksit-tg.arn
  }
}

# attach asg to alb
resource "aws_autoscaling_attachment" "alb-asg-attach" {
  autoscaling_group_name = "${aws_autoscaling_group.teksit-asg.id}"
  lb_target_group_arn    = "${aws_lb_target_group.teksit-tg.arn}"
}
