# This file provisions a highly available WordPress environment on AWS.
# The architecture includes:
# - A custom VPC with subnets across two Availability Zones.
# - An Application Load Balancer to distribute traffic.
# - An Auto Scaling Group for the WordPress instances.
# - An Amazon RDS database.
# - An Amazon EFS for shared WordPress content.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Look up the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create a VPC
resource "aws_vpc" "wordpress_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.prefix}-wordpress-vpc"
  }
}

# Create public subnets in two Availability Zones
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.prefix}-public-subnet-a"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.prefix}-public-subnet-b"
  }
}

# Create private subnets in two Availability Zones for the WordPress app
resource "aws_subnet" "private_app_subnet_a" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "${var.prefix}-private-app-subnet-a"
  }
}

resource "aws_subnet" "private_app_subnet_b" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "${var.prefix}-private-app-subnet-b"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.wordpress_vpc.id
  tags = {
    Name = "${var.prefix}-igw"
  }
}

# Create Security Groups for the load balancer, instances, RDS, and EFS
resource "aws_security_group" "alb_sg" {
  name        = "${var.prefix}-alb-sg"
  vpc_id      = aws_vpc.wordpress_vpc.id
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
}

resource "aws_security_group" "wordpress_sg" {
  name        = "${var.prefix}-wordpress-sg"
  vpc_id      = aws_vpc.wordpress_vpc.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.prefix}-rds-sg"
  vpc_id      = aws_vpc.wordpress_vpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_sg.id]
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "${var.prefix}-efs-sg"
  vpc_id      = aws_vpc.wordpress_vpc.id
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_sg.id]
  }
}

# Create an Application Load Balancer
resource "aws_lb" "wordpress_alb" {
  name                     = "${var.prefix}-alb"
  internal                 = false
  load_balancer_type       = "application"
  security_groups          = [aws_security_group.alb_sg.id]
  subnets                  = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "wordpress_tg" {
  name     = "${var.prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wordpress_vpc.id
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}

# Create a launch template for the Auto Scaling Group
resource "aws_launch_template" "wordpress_lt" {
  name_prefix   = "wordpress-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  vpc_security_group_ids = [
    aws_security_group.wordpress_sg.id,
    aws_security_group.efs_sg.id,
  ]
}

# Create the Auto Scaling Group
resource "aws_autoscaling_group" "wordpress_asg" {
  name                      = "${var.prefix}-asg"
  vpc_zone_identifier       = [aws_subnet.private_app_subnet_a.id, aws_subnet.private_app_subnet_b.id]
  desired_capacity          = 2
  max_size                  = 4
  min_size                  = 2
  target_group_arns         = [aws_lb_target_group.wordpress_tg.arn]
  health_check_type         = "ELB"
  launch_template {
    id      = aws_launch_template.wordpress_lt.id
    version = "$$Latest"
  }
  tags = [
    {
      key                 = "Name"
      value               = "wordpress-instance"
      propagate_at_launch = true
    },
  ]
}

# Create an RDS MySQL database
resource "aws_db_instance" "wordpress_db" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  identifier             = "${var.prefix}-db"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

# Create an EFS File System
resource "aws_efs_file_system" "wordpress_efs" {
  creation_token   = "${var.prefix}-efs"
  performance_mode = "generalPurpose"
  encrypted        = true
  tags = {
    Name = "${var.prefix}-efs"
  }
}

# Create EFS mount targets in each app subnet
resource "aws_efs_mount_target" "efs_mount_a" {
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = aws_subnet.private_app_subnet_a.id
  security_groups = [aws_security_group.efs_sg.id]
}
resource "aws_efs_mount_target" "efs_mount_b" {
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = aws_subnet.private_app_subnet_b.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Create an EC2 instance in each private subnet to represent a target for Ansible.
# In a real-world scenario, you would use a launch template with user data to configure the instance.
# Here we provision a couple of instances for demonstration purposes.
resource "aws_instance" "ansible_target" {
  count         = 2
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  subnet_id     = element([aws_subnet.private_app_subnet_a.id, aws_subnet.private_app_subnet_b.id], count.index)
  vpc_security_group_ids = [
    aws_security_group.wordpress_sg.id,
    aws_security_group.efs_sg.id,
  ]
  tags = {
    Name = "ansible-target-${count.index}"
  }
}

# This local-exec provisioner will create the inventory.ini file after the instances are created.
resource "null_resource" "ansible_inventory_generator" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "[webservers]" > inventory.ini
      echo "${join("\n", aws_instance.ansible_target.*.public_ip)}" >> inventory.ini
    EOT
  }
}
