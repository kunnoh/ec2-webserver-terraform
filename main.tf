terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>5.51.1"
    }
  }
}

data "aws_region" "current" {
  provider = aws
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
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.WebServer-GW.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.WebServer-GW.id
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

  # Set key permissions
  provisioner "local-exec" {
    command = "chmod 400 ${var.webserver_ssh_key}"
  }

  tags = {
    Name = "Web Server"
  }
}

resource "null_resource" "wait-web-server" {
  depends_on = [aws_instance.web-server]
  
  provisioner "remote-exec" {
    connection {
      host = aws_instance.web-server.public_dns
      user = "admin"
      private_key = file(var.webserver_ssh_key)
      timeout = "15m"
    }
    inline = ["echo 'connected to web-server!'"]
  }

  provisioner "local-exec" {
    command = "export ANSIBLE_SSH_ARGS='-o ServerAliveInterval=60 -o ServerAliveCountMax=5' && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -T 900 -i ${aws_instance.web-server.public_dns}, --user admin --private-key ${var.webserver_ssh_key} ./ansible/playbook.yml"
  }
}

