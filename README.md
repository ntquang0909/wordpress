# wordpress
I have provided the Terraform code to provision the infrastructure, including the VPC, subnets, security groups, RDS, ElastiCache, EFS, and an Auto Scaling Group for the WordPress instances. I have also included the Ansible playbook and a template for the `wp-config.php` file, which will be used to configure WordPress on the EC2 instances.

The Terraform `main.tf` and `variables.tf` files will set up the core infrastructure. The `install.sh` script is passed to the EC2 instances as `user_data` to perform the initial setup. Finally, the Ansible playbook (`playbook.yml`) and `wp-config.php.j2` template will configure the WordPress installation and connect it to the RDS and ElastiCache services.

To run the Ansible playbook, you would need to export the database and cache connection details as environment variables and run it from the Bastion Host. This is a secure approach as it avoids storing sensitive information directly in the Ansible files.

In more details, please see `Highly Available WordPress on AWS.pdf`
