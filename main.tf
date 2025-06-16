provider "aws" {
  region = "ap-south-1" # Can be any region, but should match one of your aliases for consistency
}

provider "aws" {
  region = "ap-northeast-3" # Primary region
  alias  = "primary"
}

provider "aws" {
  region = "us-west-1" # Secondary region
  alias  = "secondary"
}

# Security Group for ALB in primary region
resource "aws_security_group" "alb_sg_primary" {
  provider    = aws.primary
  name        = "alb-sg-primary"
  description = "Security group for ALB in primary region"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "PrimaryAlbSg"
  }
}

# Security Group for ALB in secondary region
resource "aws_security_group" "alb_sg_secondary" {
  provider    = aws.secondary
  name        = "alb-sg-secondary"
  description = "Security group for ALB in secondary region"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "SecondaryAlbSg"
  }
}

# Security Group for EC2 instances in primary region
resource "aws_security_group" "instance_sg_primary" {
  provider    = aws.primary
  name        = "instance-sg-primary"
  description = "Security group for instances in primary region"
  
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg_primary.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "PrimaryInstanceSg"
  }
}

# Security Group for EC2 instances in secondary region
resource "aws_security_group" "instance_sg_secondary" {
  provider    = aws.secondary
  name        = "instance-sg-secondary"
  description = "Security group for instances in secondary region"
  
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg_secondary.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "SecondaryInstanceSg"
  }
}

# EC2 Instance in primary region
resource "aws_instance" "app_primary" {
  provider          = aws.primary
  ami               = "ami-03b1b6c261a78b8e6" # Amazon Linux 2 AMI (update as needed)
  instance_type     = "t2.micro"
  security_groups   = [aws_security_group.instance_sg_primary.name]
  user_data         = <<-EOF
                    #!/bin/bash
                    yum update -y
                    yum install -y httpd
                    systemctl start httpd
                    systemctl enable httpd
                    echo "<h1>Hello from $(hostname -f) in ap-northeast-3</h1>" > /var/www/html/index.html
                    EOF

  tags = {
    Name = "PrimaryAppInstance"
  }
}


# EC2 Instance in secondary region
resource "aws_instance" "app_secondary" {
  provider          = aws.secondary
  ami               = "ami-0cbad6815f3a09a6d" # Amazon Linux 2 AMI (update as needed)
  instance_type     = "t2.micro"
  security_groups   = [aws_security_group.instance_sg_secondary.name]
  user_data         = <<-EOF
                    #!/bin/bash
                    yum update -y
                    yum install -y httpd
                    systemctl start httpd
                    systemctl enable httpd
                    echo "<h1>Hello from $(hostname -f) in us-west-1</h1>" > /var/www/html/index.html
                    EOF

  tags = {
    Name = "SecondaryAppInstance"
  }
}

# ALB in primary region
resource "aws_lb" "primary_alb" {
  provider           = aws.primary
  name               = "primary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_primary.id]
  subnets            = data.aws_subnets.primary_public_subnets.ids

  enable_deletion_protection = false

  tags = {
    Name = "PrimaryALB"
  }
}

# ALB in secondary region
resource "aws_lb" "secondary_alb" {
  provider           = aws.secondary
  name               = "secondary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_secondary.id]
  subnets            = data.aws_subnets.secondary_public_subnets.ids

  enable_deletion_protection = false

  tags = {
    Name = "SecondaryALB"
  }
}

# Target group for primary ALB
resource "aws_lb_target_group" "primary_tg" {
  provider    = aws.primary
  name        = "primary-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.primary_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

# Target group for secondary ALB
resource "aws_lb_target_group" "secondary_tg" {
  provider    = aws.secondary
  name        = "secondary-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.secondary_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

# ALB listener for primary region
resource "aws_lb_listener" "primary_listener" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.primary_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary_tg.arn
  }
}

# ALB listener for secondary region
resource "aws_lb_listener" "secondary_listener" {
  provider          = aws.secondary
  load_balancer_arn = aws_lb.secondary_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.secondary_tg.arn
  }
}

# Target group attachment for primary region
resource "aws_lb_target_group_attachment" "primary_attachment" {
  provider         = aws.primary
  target_group_arn = aws_lb_target_group.primary_tg.arn
  target_id        = aws_instance.app_primary.id
  port             = 80
}

# Target group attachment for secondary region
resource "aws_lb_target_group_attachment" "secondary_attachment" {
  provider         = aws.secondary
  target_group_arn = aws_lb_target_group.secondary_tg.arn
  target_id        = aws_instance.app_secondary.id
  port             = 80
}

# Data sources to get VPC and subnets for primary region
data "aws_vpc" "primary_vpc" {
  provider = aws.primary
  default  = true
}

data "aws_subnets" "primary_public_subnets" {
  provider = aws.primary
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary_vpc.id]
  }
}

# Data sources to get VPC and subnets for secondary region
data "aws_vpc" "secondary_vpc" {
  provider = aws.secondary
  default  = true
}

data "aws_subnets" "secondary_public_subnets" {
  provider = aws.secondary
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.secondary_vpc.id]
  }
}

# Global Accelerator
resource "aws_globalaccelerator_accelerator" "app_accelerator" {
  name            = "app-global-accelerator"
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled   = false
    flow_logs_s3_bucket = ""
    flow_logs_s3_prefix = ""
  }
}

# Listener for HTTP traffic
resource "aws_globalaccelerator_listener" "app_listener" {
  accelerator_arn = aws_globalaccelerator_accelerator.app_accelerator.id
  client_affinity = "NONE"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

# Endpoint Group for primary region (using ALB)
resource "aws_globalaccelerator_endpoint_group" "primary_region" {
  listener_arn = aws_globalaccelerator_listener.app_listener.id

  endpoint_configuration {
    endpoint_id = aws_lb.primary_alb.arn
    weight      = 100
  }

  endpoint_group_region         = "ap-northeast-3"
  health_check_port             = 80
  health_check_protocol         = "HTTP"
  health_check_path             = "/"
  threshold_count               = 3
  traffic_dial_percentage       = 100
}

# Endpoint Group for secondary region (using ALB)
resource "aws_globalaccelerator_endpoint_group" "secondary_region" {
  listener_arn = aws_globalaccelerator_listener.app_listener.id

  endpoint_configuration {
    endpoint_id = aws_lb.secondary_alb.arn
    weight      = 100
  }

  endpoint_group_region         = "us-west-1"
  health_check_port             = 80
  health_check_protocol         = "HTTP"
  health_check_path             = "/"
  threshold_count               = 3
  traffic_dial_percentage       = 100
}