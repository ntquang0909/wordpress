#!/bin/bash

# NOTE: This script is provided as a simple example for a single-server setup.
# The highly available architecture requires the Ansible playbook for proper EFS mounting
# and database configuration across multiple instances.

# Update package lists and install Apache, MySQL, and PHP
sudo apt-get update -y
sudo apt-get install -y apache2 php libapache2-mod-php php-mysql php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc

# Start and enable services
sudo systemctl start apache2
sudo systemctl enable apache2