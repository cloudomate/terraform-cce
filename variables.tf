variable "vpc_name" {
  default = "cce"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}


variable "subnet_name" {
  default = "cce-nodes"
}


variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "subnet_gateway_ip" {
  default = "10.0.1.1"
}

variable "primary_dns" {
  default = "100.125.3.250"
}

variable "secondary_dns" {
  default="100.125.2.14"
}	

variable "public-key" {}

variable "bastion_os" {
  default="Ubuntu 20.04 server 64bit"
}