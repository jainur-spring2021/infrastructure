module "vpc1" {
    source = "../../modules/vpc"
    aws_region = "${var.aws_region}"
    aws_access_key_id = "${var.aws_access_key_id}"
    aws_secret_key_id = "${var.aws_secret_key_id}"
    aws_vpc_cidr_block = "${var.aws_vpc_cidr_block}"
    aws_subnet1_cidr = "${var.aws_subnet1_cidr}"
    aws_subnet2_cidr = "${var.aws_subnet2_cidr}"
    aws_subnet3_cidr = "${var.aws_subnet3_cidr}"
    aws_vpc_name = "${var.aws_vpc_name}"
    aws_route_gateway_destination_cidr_block = "${var.aws_route_gateway_destination_cidr_block}"
}