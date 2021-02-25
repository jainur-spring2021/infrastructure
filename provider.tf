provider "aws" {
    region = "us-east-1"
}

resource "aws_vpc" "csye6225_vpc" {
    cidr_block       = "190.160.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true
}

resource "aws_subnet" "subnet1" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "190.160.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "190.160.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_subnet" "subnet3" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "190.160.3.0/24"
  availability_zone = "us-east-1c"
}

resource "aws_internet_gateway" "csye6225_internet_gateway" {
  vpc_id = "${aws_vpc.csye6225_vpc.id}"
}

resource "aws_route" "gateway_route" {
  route_table_id = aws_vpc.csye6225_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.csye6225_internet_gateway.id
}


