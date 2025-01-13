output "instance_public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.terraform_server.public_ip
}

output "instance_private_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.terraform_server.public_ip
}

