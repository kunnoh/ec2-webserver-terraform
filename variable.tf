variable "webserver_ssh_key" {
  description = "web server ssh public key"
  type = string
  default = ".terraform/local/public_key"
}

variable "ami" {
  description = "id for os type"
  type = string
  default = "ami-0588c11374527e516"
}

variable "ec2_instance_type" {
    description = "type of instance to provision"
    type = string
    default = "t2.micro"
}

variable "availability_zone" {
    description = "availability region of your system"
    type = string
    default = "eu-central-1a"
}
