variable "aws_region" {
    default = "us-east-1"
}

variable "aws_vpc_name" {
    default = "csye6225"
}

variable "aws_vpc_cidr_block" {
    default = "190.160.0.0/16"
}

variable "aws_subnet1_cidr"{
  default = "190.160.1.0/24"
}

variable "aws_subnet2_cidr"{
  default = "190.160.2.0/24"
}

variable "aws_subnet3_cidr"{
  default = "190.160.3.0/24"
}

variable "aws_route_gateway_destination_cidr_block"{
  default = "0.0.0.0/0"
}

variable aws_route53_zone_name{

}

