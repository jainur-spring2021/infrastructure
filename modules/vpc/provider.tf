provider "aws" {
    region = var.aws_region
}

resource "aws_vpc" "csye6225_vpc" {
    cidr_block       = var.aws_vpc_cidr_block
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true
    enable_classiclink_dns_support = true
    tags = {
        Name = var.aws_vpc_name
    }
}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.csye6225_vpc.id
  cidr_block = var.aws_subnet1_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[0]
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.csye6225_vpc.id
  cidr_block = var.aws_subnet2_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[1]
}

resource "aws_subnet" "subnet3" {
  vpc_id     = aws_vpc.csye6225_vpc.id
  cidr_block = var.aws_subnet3_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[2]
}

resource "aws_internet_gateway" "csye6225_internet_gateway" {
  vpc_id = aws_vpc.csye6225_vpc.id
}

resource "aws_route" "gateway_route" {
  route_table_id = aws_vpc.csye6225_vpc.main_route_table_id
  destination_cidr_block = var.aws_route_gateway_destination_cidr_block
  gateway_id = aws_internet_gateway.csye6225_internet_gateway.id
}

resource "aws_security_group" "lb-security-group" {
  description = "Allow TCP traffic on ports 22, 80, 43, 3000"
  vpc_id      = aws_vpc.csye6225_vpc.id


  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NODE SERVER"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Egress rule"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "load balancer"
  }
}

resource "aws_security_group" "database-security-group" {
  description = "Allow TCP traffic on ports 3306 for mysql"
  vpc_id      = aws_vpc.csye6225_vpc.id

  ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups =  [aws_security_group.ec2-security-group.id]
  }

  tags = {
    Name = "database"
  }
}

resource "aws_security_group" "ec2-security-group" {
  description = "Allow traffic from load balancer"
  vpc_id      = aws_vpc.csye6225_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.lb-security-group.id]
  }

  ingress {
    description = "Node Server"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.lb-security-group.id]
  }

  egress {
    description = "Egress rule"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2_security_group"
  }
}

resource "aws_kms_key" "encryption_key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "s3-csye-6225" {
  bucket = var.aws_s3_bucket_name
  acl    = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.encryption_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  versioning {
    enabled = true
  }
  lifecycle_rule{
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  tags = {
    Name = "RDS Subnet Group"
  }
}

resource "aws_kms_key" "rds_encryption" {
  description             = "KMS key for RDS"
  key_usage               = "ENCRYPT_DECRYPT"
  policy                  = "${file("policy.json")}"
  is_enabled              = true
  tags = {
    "Name" = "KMS for RDS"
  }
}

resource "aws_db_instance" "rds_instance" {
  identifier = var.aws_db_identifier
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "csye6225"
  username             = "csye6225"
  password             = var.aws_db_password
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  multi_az = false
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database-security-group.id]
}

resource "aws_iam_policy" "IAM_policy" {
  name = "WebAppS3"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "kms:GenerateDataKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObjectVersion",
                "s3:ListBucketVersions",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:GetObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.s3-csye-6225.bucket}/*",
                "arn:aws:s3:::${aws_s3_bucket.s3-csye-6225.bucket}"
            ]
        }
    ]
  })
}

resource "aws_iam_policy" "IAM_policy_CodeDeploy_EC2_S3" {
  name = "CodeDeploy-EC2-S3"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:ListBucketVersions",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${var.code_deploy_S3_bucket}/*",
                "arn:aws:s3:::${var.code_deploy_S3_bucket}"
            ]
        }
    ]
  })
}

resource "aws_iam_policy" "IAM_policy_GH_Upload_To_S3" {
  name = "GH-Upload-To-S3"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:ListBucketVersions",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${var.code_deploy_S3_bucket}/*",
                "arn:aws:s3:::${var.code_deploy_S3_bucket}"
            ]
        }
    ]
  })
}



resource "aws_iam_policy" "IAM_policy_GH_Code_Deploy" {
  name = "GH-Code-Deploy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision"
        ],
        "Resource": [
          "arn:aws:codedeploy:us-east-1:${var.acc_id}:application:csye6225-webapp"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment"
        ],
        "Resource": [
          "*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "codedeploy:GetDeploymentConfig"
        ],
        "Resource": [
          "arn:aws:codedeploy:us-east-1:${var.acc_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
          "arn:aws:codedeploy:us-east-1:${var.acc_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
          "arn:aws:codedeploy:us-east-1:${var.acc_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "IAM_role" {
  name = "EC2-CSYE6225"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "IAM_policy_attachment" {
  role       = aws_iam_role.IAM_role.name
  policy_arn = aws_iam_policy.IAM_policy.arn
}

resource "aws_iam_role_policy_attachment" "IAM_policy_attachment1" {
  role       = aws_iam_role.IAM_role.name
  policy_arn = aws_iam_policy.IAM_policy_CodeDeploy_EC2_S3.arn
}

resource "aws_iam_role_policy_attachment" "IAM_policy_attachment2" {
  role       = aws_iam_role.IAM_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "IAM_policy_attachment3" {
  role       = aws_iam_role.IAM_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role" "Code_Deploy_Service_Role" {
  name = "CodeDeployServiceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "Code_deploy_role_service_policy_attachment" {
  role       = aws_iam_role.Code_Deploy_Service_Role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

data "aws_ami" "ami" {
  owners           = [var.aws_ami_owner]
  most_recent = true
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.IAM_role.name
}

resource "aws_codedeploy_app" "code_deploy_app" {
  compute_platform =  "Server"
  name = "csye6225-webapp"
}

resource "aws_codedeploy_deployment_group" "code_deploy_deployment_group" {
  app_name               = aws_codedeploy_app.code_deploy_app.name
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  deployment_group_name  = "csye6225-webapp-deployment"
  service_role_arn       = aws_iam_role.Code_Deploy_Service_Role.arn
  autoscaling_groups = [aws_autoscaling_group.autoscaling_group.name]
  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "Code Deploy Instance"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  load_balancer_info {
    target_group_info {
        name = aws_lb_target_group.target_group.name
    }
  }
}

data "aws_route53_zone" "hosted_zone" {
  name         = var.aws_route53_zone_name
}

resource "aws_route53_record" "route53_record" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = data.aws_route53_zone.hosted_zone.name
  type    = "A"
  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}

data "aws_iam_user" "deploy-user" {
  user_name = "ghactions"
}

resource "aws_iam_user_policy_attachment" "cicd-policy-attach" {
  user       = data.aws_iam_user.deploy-user.user_name
  policy_arn = aws_iam_policy.IAM_policy_GH_Upload_To_S3.arn
}

resource "aws_iam_user_policy_attachment" "cicd-policy-attach1" {
  user       = data.aws_iam_user.deploy-user.user_name
  policy_arn = aws_iam_policy.IAM_policy_GH_Code_Deploy.arn
}

resource "aws_iam_policy" "lambda_codedeploy_policy" {
  name = "lambda_codedeploy_policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "lambda:UpdateFunctionEventInvokeConfig",
                "lambda:TagResource",
                "lambda:UpdateEventSourceMapping",
                "lambda:InvokeFunction",
                "lambda:PublishLayerVersion",
                "lambda:DeleteProvisionedConcurrencyConfig",
                "lambda:UpdateFunctionConfiguration",
                "lambda:InvokeAsync",
                "lambda:UntagResource",
                "lambda:PutFunctionConcurrency",
                "lambda:UpdateAlias",
                "lambda:UpdateFunctionCode",
                "lambda:DeleteLayerVersion",
                "lambda:PutProvisionedConcurrencyConfig",
                "lambda:DeleteAlias",
                "lambda:PutFunctionEventInvokeConfig",
                "lambda:DeleteFunctionEventInvokeConfig",
                "lambda:DeleteFunction",
                "lambda:PublishVersion",
                "lambda:DeleteFunctionConcurrency",
                "lambda:DeleteEventSourceMapping",
                "lambda:CreateAlias"
            ],
            "Resource": "arn:aws:lambda:${var.aws_region}:${var.acc_id}:function:${aws_lambda_function.send_email.function_name}"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "lambda:UpdateFunctionCode",
                "lambda:CreateEventSourceMapping"
            ],
            "Resource": "arn:aws:lambda:${var.aws_region}:${var.acc_id}:function:${aws_lambda_function.send_email.function_name}"
        }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "cicd-policy-attach2" {
  user       = data.aws_iam_user.deploy-user.user_name
  policy_arn = aws_iam_policy.lambda_codedeploy_policy.arn
}

# resource "aws_instance" "ec2instance" {
  # ami = data.aws_ami.ami.id
  # instance_type = "t2.micro"
  # key_name = "csye6225"
  # vpc_security_group_ids = [aws_security_group.application-security-group.id]
  # subnet_id = aws_subnet.subnet1.id
  # associate_public_ip_address = true
  # root_block_device {
      # volume_type = "gp2"
      # volume_size = 20
      # delete_on_termination = true
  # }
  # depends_on = [aws_db_instance.rds_instance]
  # iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  # user_data = <<-EOF
         #!/bin/bash
         # echo "export aws_region=${var.aws_region}" | sudo tee -a /etc/environment
         # echo "export s3_bucket_name=${var.aws_s3_bucket_name}" | sudo tee -a /etc/environment
         # echo "export db_instance_username=${aws_db_instance.rds_instance.username}" | sudo tee -a /etc/environment
         # echo "export db_instance_password=${var.aws_db_password}" | sudo tee -a /etc/environment
         # echo "export ami_id=${data.aws_ami.ami.id}" | sudo tee -a /etc/environment
         # echo "export db_instance_name=${var.aws_db_identifier}" | sudo tee -a /etc/environment
         # echo "export db_instance_hostname=${aws_db_instance.rds_instance.address}" | sudo tee -a /etc/environment
     # EOF

     # tags = {
       # Name = "Code Deploy Instance"
     # }
# }

resource "aws_launch_configuration" "launch_config" {
  name = "asg_launch_config"
  image_id      = data.aws_ami.ami.id
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  key_name = "csye6225"
  security_groups = [aws_security_group.ec2-security-group.id]
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
    delete_on_termination = true
    encrypted = true
  }
  depends_on = [aws_db_instance.rds_instance]
  user_data = <<-EOF
         #!/bin/bash
         apt-get install -y apache2
         systemctl start apache2
         systemctl enable apache2
         echo "export aws_region=${var.aws_region}" | sudo tee -a /etc/environment
         echo "export s3_bucket_name=${var.aws_s3_bucket_name}" | sudo tee -a /etc/environment
         echo "export db_instance_username=${aws_db_instance.rds_instance.username}" | sudo tee -a /etc/environment
         echo "export db_instance_password=${var.aws_db_password}" | sudo tee -a /etc/environment
         echo "export ami_id=${data.aws_ami.ami.id}" | sudo tee -a /etc/environment
         echo "export db_instance_name=${var.aws_db_identifier}" | sudo tee -a /etc/environment
         echo "export db_instance_hostname=${aws_db_instance.rds_instance.address}" | sudo tee -a /etc/environment
         echo "export topic_arn=${aws_sns_topic.notifications.arn}" | sudo tee -a /etc/environment
    EOF
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                 = "autoscaling_group"
  launch_configuration = aws_launch_configuration.launch_config.name
  min_size             = 3
  max_size             = 5
  default_cooldown     = 60
  tag {
    key   = "Name"
    propagate_at_launch = true
    value = "Code Deploy Instance"
  }
  target_group_arns   = [aws_lb_target_group.target_group.arn]
  # availability_zones  = [data.aws_availability_zones.available_zones.names[0]]
  vpc_zone_identifier = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  health_check_grace_period = 900
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmHigh" {
  alarm_name          = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 05

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }

  alarm_description = "Scale-up if CPU > 5% for 1 minutes"
  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmLow" {
  alarm_name          = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 03

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }

  alarm_description = "Scale-down if CPU < 3% for 5 minutes"
  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]
}

resource "aws_lb" "load_balancer" {
  name               = "loadBalancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet1.id,aws_subnet.subnet2.id,aws_subnet.subnet3.id]
  ip_address_type    = "ipv4"
  security_groups = [aws_security_group.lb-security-group.id]
}

resource "aws_lb_target_group" "target_group" {
  name     = "targetGroup"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.csye6225_vpc.id
  health_check {
    enabled  = true
    interval = 30
    path = "/"
    protocol = "HTTP"
    port = 80
    healthy_threshold = 3
    unhealthy_threshold = 5 
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:205467980008:certificate/f3e1e4b3-b692-4f9d-877d-acb16a09be99"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_sns_topic" "notifications" {
  name = "user-notifications-topic"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_role_policies" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_role_policies1" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

resource "aws_lambda_function" "send_email" {
  filename      = "send-email.zip"
  function_name = "send-email"
  role          = aws_iam_role.lambda_role.arn
  handler       = "send-email.handler"
  runtime = "nodejs14.x"
}

resource "aws_sns_topic_subscription" "subscription" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.send_email.arn
}

resource "aws_lambda_permission" "invoke_lambda_through_SNS" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_email.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.notifications.arn
}
