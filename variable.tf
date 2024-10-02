variable "webserver_ssh_key" {
  description = "web server ssh private key"
  type = string
  default = ".terraform/local/private_key"
}

variable "ami" {
  description = "AMI for os type"
  type = string
  default = "ami-0588c11374527e516"
}

variable "ec2_instance_type" {
  description = "type of instance to provision"
  type = string
  default = "t2.micro"
}

variable "ec2_username" {
  description = "server username"
  type = string
  default = "admin"
}

variable "availability_zone" {
  description = "availability region of your system"
  type = string
  default = "eu-central-1a"
}
