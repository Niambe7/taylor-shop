aws_region = "eu-west-3"
env        = "dev"
owner      = "team-dev"


cidr = "10.0.0.0/16"
azs  = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]


public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_app_cidrs   = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
private_db_cidrs    = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]


# DB
db_name           = "prestashop"
db_user           = "ps_user"
db_pass_ssm_param = "/taylor/dev/db_password"


# RDS
rds_instance_class = "db.t3.micro"
rds_multi_az       = false


# Docker image tag (voir Docker Hub / devdocs)
prestashop_image_tag = "latest"