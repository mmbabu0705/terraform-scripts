provider "aws" {
  region = "ap-south-1"  # Change this to your desired region
}

# VPC 1
resource "aws_vpc" "vpc1" {
  cidr_block = "12.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc1"
  }
}

# VPC 2
resource "aws_vpc" "vpc2" {
  cidr_block = "13.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc2"
  }
}

# Create a subnet1
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "12.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "subnet1"
  }
}
# Create a subnet2
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.vpc2.id
  cidr_block = "13.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "subnet1"
  }
}

# igw1
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "igw1"
  }
}

# igw2
resource "aws_internet_gateway" "igw2" {
  vpc_id = aws_vpc.vpc2.id

  tags = {
    Name = "igw2"
  }
}

# Route Table for VPC 1
resource "aws_route_table" "rt_vpc1" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = {
    Name = "rt_vpc1"
  }
}

# Route Table for VPC 2
resource "aws_route_table" "rt_vpc2" {
  vpc_id = aws_vpc.vpc2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw2.id
  }

  tags = {
    Name = "rt_vpc2"
  }
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = aws_vpc.vpc1.id
  peer_vpc_id = aws_vpc.vpc2.id
  auto_accept = true  # Set to false if peering is across different AWS accounts
}

# Route to VPC 2 from VPC 1
resource "aws_route" "route_vpc1_to_vpc2" {
  route_table_id            = aws_route_table.rt_vpc1.id
  destination_cidr_block    = aws_vpc.vpc2.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# Route to VPC 1 from VPC 2
resource "aws_route" "route_vpc2_to_vpc1" {
  route_table_id            = aws_route_table.rt_vpc2.id
  destination_cidr_block    = aws_vpc.vpc1.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# Associate Route Table with Subnet in VPC 1
resource "aws_route_table_association" "assoc_vpc1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt_vpc1.id
}

# Associate Route Table with Subnet in VPC 2
resource "aws_route_table_association" "assoc_vpc2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt_vpc2.id
}
# Create a security group 1
resource "aws_security_group" "vpc_sg_1" {
  name        = "vpc_sg_1"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc1.id

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
  vpc_id      = aws_vpc.vpc2.id

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
  subnet_id     =  aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.vpc_sg_1.id]
  associate_public_ip_address = true
  user_data     = "${file("server-1.sh")}" 

  tags = {
    Name = "server-1"
  }
}
# creat EC2 instance with server-2
resource "aws_instance" "test_server_2" {
  ami           = "ami-053b12d3152c0cc71" # ap-south-1
  instance_type = "t2.micro"
  key_name      = "db-server"
  subnet_id     =  aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.vpc_sg_2.id]
  associate_public_ip_address = true
  user_data     = "${file("server-2.sh")}" 

  tags = {
    Name = "server-2"
  }
}
