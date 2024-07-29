terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>5.51.1"
    }
  }
}

data "aws_region" "current" {
  provider = aws.EuropeGermany
}

# Key-pair
resource "tls_private_key" "webserver_rsa_4096" {
  algorithm   = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "webserver_ssh_key" {
  key_name   = var.webserver_ssh_key
  public_key = tls_private_key.webserver_rsa_4096.public_key_openssh
}

resource "local_file" "webserver_private_key" {
  content = tls_private_key.webserver_rsa_4096.private_key_openssh
  filename = var.webserver_ssh_key
}

# VPC
resource "aws_vpc" "WebServer-Vpc" {
  cidr_block = "10.68.9.0/28"
  enable_dns_hostnames = true
  tags = {
    Name = "web-server"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "WebServer-GW" {
  vpc_id = aws_vpc.WebServer-Vpc.id
  tags = {
    Name = "Web Server Internet Gateway"
  }
}

# Route Table
resource "aws_route_table" "WebServer-Routing-Table" {
  vpc_id = aws_vpc.WebServer-Vpc.id
  route {
    cidr_block = "10.68.9.0/28"
    gateway_id = aws_internet_gateway.WebServer-GW.id
  }
  route {
    ipv6_cidr_block = "::/0"
    egress_only_gateway_id = aws_internet_gateway.WebServer-GW.id
  }
  tags = {
    Name = "WebServer Routing Table"
  }
}

# Subnet
resource "aws_subnet" "WebServer-Subnet" {
  vpc_id     = aws_vpc.WebServer-Vpc.id
  cidr_block = aws_vpc.WebServer-Vpc.cidr_block
  availability_zone = var.availability_zone
  tags = {
    Name = "WebServer Subnet"
  }
}

# Associate subnet with Route Table
resource "aws_route_table_association" "WebServer-Subnet_Association" {
  subnet_id      = aws_subnet.WebServer-Subnet.id
  route_table_id = aws_route_table.WebServer-Routing-Table.id
}

# Security Group. Allow port 22,80,443
resource "aws_security_group" "allow_traffic" {
  name = "webserver-SG"
  description = "Allow http, https, ssh inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.WebServer-Vpc.id

  ingress {
    description = "Allow HTTPS"
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Allow SSH"
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow webserver http, https and ssh"
  }
}

# ec2 Instance
resource "aws_instance" "web-server" {
  ami = "ami-075d8cd2ff03fa6e9"
  instance_type = var.ec2_instance_type
  key_name = aws_key_pair.webserver_ssh_key.key_name
  associate_public_ip_address = true
  availability_zone = var.availability_zone

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt upgrade -y",
      "sudo apt install nginx ufw -y",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "sudo ufw allow 80",
      "sudo ufw allow 22",
      "sudo ufw allow 443",
      "sudo systemctl enable ufw",
      "sudo systemctl start ufw",
    ]

    connection {
      type        = "ssh"
      user        = "admin"
      private_key = file("${var.webserver_ssh_key}")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "Web Server"
  }
}
