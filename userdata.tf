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

# Create a VPC
resource "aws_vpc" "test_vpc" {
  cidr_block       = "12.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "test_vpc"
  }
}

# Create a public-subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.test_vpc.id
  cidr_block = "12.0.1.0/24"

  tags = {
    Name = "public_subnet"
  }
}

# Create a Internet Gateway
resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "test_igw"
  }
}

# Create a Route Table
resource "aws_route_table" "test_rt" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test_igw.id
  }

  tags = {
    Name = "test_rt"
  }
}

# Need to associate subnet to route table
resource "aws_route_table_association" "subnetassociate_rt" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.test_rt.id
}

# Create a security group 
resource "aws_security_group" "test_vpc_sg" {
  name        = "test_vpc_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.test_vpc.id

  tags = {
    Name = "test_vpc_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.test_vpc_sg.id
  cidr_ipv4         = aws_vpc.test_vpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_http" {
  security_group_id = aws_security_group.test_vpc_sg.id
  cidr_ipv4         = aws_vpc.test_vpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_https" {
  security_group_id = aws_security_group.test_vpc_sg.id
  cidr_ipv4         = aws_vpc.test_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_all" {
  security_group_id = aws_security_group.test_vpc_sg.id
  cidr_ipv4         = aws_vpc.test_vpc.cidr_block
  from_port         = 0
  ip_protocol       = "tcp"
  to_port           = 65535
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.test_vpc_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# creat EC2 instance with userdata
resource "aws_instance" "test_server" {
  ami           = "ami-053b12d3152c0cc71" # ap-south-1
  instance_type = "t2.micro"
  key_name      = "db-server"
  user_data     = "${file("apache2.sh")}" 

  tags = {
    Name = "test_server"
  }
}
