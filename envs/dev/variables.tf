variable "aws_region" { type = string }
variable "env" { type = string }
variable "owner" { type = string }


variable "cidr" { type = string }
variable "azs" { type = list(string) }


variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_cidrs" { type = list(string) }
variable "private_db_cidrs" { type = list(string) }


variable "db_name" { type = string }
variable "db_user" { type = string }
variable "db_pass_ssm_param" { type = string } # ex: /taylor/dev/db_password
variable "rds_instance_class" { type = string }
variable "rds_multi_az" { type = bool }
variable "prestashop_image_tag" { type = string }