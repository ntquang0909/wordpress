# This file defines the variables used in the main.tf configuration.
# Customize these values for your specific deployment.

variable "aws_region" {
  description = "The AWS region to deploy the infrastructure in."
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "A unique prefix for all created resources."
  type        = string
  default     = "my-wp-ha"
}

variable "instance_type" {
  description = "The EC2 instance type for the WordPress servers."
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "The name of the SSH key pair to use for EC2 instances."
  type        = string
}

variable "db_instance_class" {
  description = "The RDS instance class for the database."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "The name for the WordPress database."
  type        = string
  default     = "wordpressdb"
}

variable "db_username" {
  description = "The master username for the RDS database."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "The master password for the RDS database."
  type        = string
  sensitive   = true
}