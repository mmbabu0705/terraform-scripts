# Write the terraform script for setup natgateway
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
resource "aws_vpc" "test-vpc" {
  cidr_block       = "12.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "test-vpc"
  }
}

# create public-subnet with test-vpc
resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.test-vpc.id
  availability_zone       = "ap-south-1a"
  cidr_block = "12.0.3.0/24"

  tags = {
    Name = "public-subnet"
  }
}

# create private-subnet with test-vpc
resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.test-vpc.id
  availability_zone       = "ap-south-1a"
  cidr_block = "12.0.4.0/24"

  tags = {
    Name = "private-subnet"
  }
}

# create Internet gateway with test-vpc
resource "aws_internet_gateway" "public-igw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "public-igw"
  }
}

# create public-route table
resource "aws_route_table" "public-RT" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public-igw.id
  }

  tags = {
    Name = "public-RT"
  }
}

# create private-route table
resource "aws_route_table" "private-RT" {
    vpc_id = aws_vpc.test-vpc.id

    tags = {
        Name = "private-RT"
    }
}

# create natgateway with public-subnet
resource "aws_eip" "nat_eip" {
  domain   = "vpc"
}
resource "aws_nat_gateway" "test_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public-subnet.id

  tags = {
    Name = "test-nat"
  }
}

# subnet association
resource "aws_route_table_association" "associate-public-subnet" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-RT.id
}
resource "aws_route_table_association" "associate-private-subnet" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private-RT.id
}

# natgateway association
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private-RT.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.test_nat.id
}

# Create a security group 1
resource "aws_security_group" "vpc_sg_1" {
  name        = "vpc_sg_1"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  tags = {
    Name = "vpc_sg_1"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_1" {
  security_group_id = aws_security_group.vpc_sg_1.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  ip_protocol       = "tcp"
  to_port           = 65535
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_1" {
  security_group_id = aws_security_group.vpc_sg_1.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Create a security group 2
resource "aws_security_group" "vpc_sg_2" {
  name        = "vpc_sg_2"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  tags = {
    Name = "vpc_sg_2"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_2" {
  security_group_id = aws_security_group.vpc_sg_2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  ip_protocol       = "tcp"
  to_port           = 65535
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_2" {
  security_group_id = aws_security_group.vpc_sg_2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# creat EC2 instance with server-1
resource "aws_instance" "test_server_1" {
  ami           = "ami-053b12d3152c0cc71" # ap-south-1
  instance_type = "t2.micro"
  key_name      = "db-server"
  subnet_id     =  aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.vpc_sg_1.id]
  associate_public_ip_address = true
 
  tags = {
    Name = "public-server"
  }
}
# creat EC2 instance with server-2
resource "aws_instance" "test_server_2" {
  ami           = "ami-053b12d3152c0cc71" # ap-south-1
  instance_type = "t2.micro"
  key_name      = "master-node-1"
  subnet_id     =  aws_subnet.private-subnet.id
  vpc_security_group_ids = [aws_security_group.vpc_sg_2.id]
  associate_public_ip_address = false
  
  tags = {
    Name = "private-server"
  }
}
