# Write the terarform script to create EC2 instance
provider "aws" {
    region     = "ap-south-1"
    access_key = ""
    secret_key = ""
  }
  resource "aws_instance" "dev_server" {
    ami           = "ami-053b12d3152c0cc71"
    instance_type = "t2.micro"
    key_name      = "db-server"
    tags = {
        Name = "dev_server"
    }

  }
