provider "aws" {
    region = "${var.aws_region}"
}

resource "aws_vpc" "csye6225_vpc" {
    cidr_block       = "${var.aws_vpc_cidr_block}"
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "${var.aws_vpc_name}"
    }
}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

resource "aws_subnet" "subnet1" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "${var.aws_subnet1_cidr}"
  availability_zone = data.aws_availability_zones.available_zones.names[0]
}

resource "aws_subnet" "subnet2" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "${var.aws_subnet2_cidr}"
  availability_zone = data.aws_availability_zones.available_zones.names[1]
}

resource "aws_subnet" "subnet3" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "${var.aws_subnet3_cidr}"
  availability_zone = data.aws_availability_zones.available_zones.names[2]
}

resource "aws_internet_gateway" "csye6225_internet_gateway" {
  vpc_id = "${aws_vpc.csye6225_vpc.id}"
}

resource "aws_route" "gateway_route" {
  route_table_id = aws_vpc.csye6225_vpc.main_route_table_id
  destination_cidr_block = "${var.aws_route_gateway_destination_cidr_block}"
  gateway_id = aws_internet_gateway.csye6225_internet_gateway.id
}


