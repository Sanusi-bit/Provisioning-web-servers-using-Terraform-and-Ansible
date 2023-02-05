variable "vpc_name" {
  description = "Value of the name tag for the vpc"
  type = string
}   

variable "vpc_cidr_block" {
  description = "Value for the VPC CIDR Block"
  type = string
}

variable "route_table_name" {
  description = "Value of the name tag for the Route table"
}

variable "public_subnet" {
  description = "CIDR blocks for the public subnet"
  type = list(string)
  default = []
}

variable "load-balancer-sg" {
  description = "Value of the name for the load balancer's security group"
  type = string
}

variable "instance-sg" {
  description = "Value of the name for the Instance's security group"
  type = string
}

variable "instance_ami" {
  description = "Value of the AMI ID for the EC2 instances"
  type = string
}

variable "instance_type" {
  description = "Value of the Instance type for the EC2 instances"
  type = string
}

variable "lb-name" {
  description = "Value of the Name for the Load balancer"
  type = string
}

variable "tg-name" {
  description = "Value of the Name for the Load balancer's Target group"
  type = string
}

variable "domain_name" {
  type        = string
  description = "Domain name"
}