terraform {
  required_version = ">= 1.7.0"
}


module "networking" {
  source              = "../../modules/networking"
  name                = "taylor-${var.env}"
  cidr                = var.cidr
  azs                 = var.azs
  public_subnet_cidrs = var.public_subnet_cidrs
  private_app_cidrs   = var.private_app_cidrs
  private_db_cidrs    = var.private_db_cidrs
  single_nat_gateway  = true
}


module "security" {
  source = "../../modules/security"
  vpc_id = module.networking.vpc_id
}


# IAM (pour SSM + lecture du secret SSM)
module "iam" {
  source                 = "../../modules/iam"
  db_password_param_name = var.db_pass_ssm_param
}

# ASG EC2 qui déploie PrestaShop (Docker)
module "asg" {
  source = "../../modules/asg"

  # région
  region = var.aws_region

  # réseau + sécurité
  subnet_ids            = module.networking.private_app_subnet_ids
  security_group_id     = module.security.app_sg_id
  instance_profile_name = module.iam.instance_profile_name

  # attachement au TG de l'ALB
  alb_tg_arn = module.alb.tg_arn
  alb_dns_name = module.alb.alb_dns_name

  # DB + secret
  db_endpoint            = module.rds.endpoint
  db_name                = var.db_name
  db_user                = var.db_user
  db_password_param_name = var.db_pass_ssm_param

  # EFS + image
  efs_id               = module.efs.efs_id
  prestashop_image_tag = var.prestashop_image_tag
}


# Lire le mot de passe DB depuis SSM (SecureString)
data "aws_ssm_parameter" "db_password" {
  name            = var.db_pass_ssm_param
  with_decryption = true
}


# RDS (password injecté via variable; pour dev on le prend depuis local var)
module "rds" {
  source                 = "../../modules/rds"
  db_name                = var.db_name
  username               = var.db_user
  password               = data.aws_ssm_parameter.db_password.value # <-- important
  subnet_ids             = module.networking.private_db_subnet_ids
  vpc_security_group_ids = [module.security.rds_sg_id]
  instance_class         = var.rds_instance_class
  multi_az               = var.rds_multi_az
}



# EFS monté sur les subnets privés app
module "efs" {
  source            = "../../modules/efs"
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.private_app_subnet_ids
  security_group_id = module.security.efs_sg_id
}


# ALB en subnets publics
module "alb" {
  source            = "../../modules/alb"
  name              = "taylor-${var.env}-alb"
  subnet_ids        = module.networking.public_subnet_ids
  security_group_id = module.security.alb_sg_id
  vpc_id            = module.networking.vpc_id
}


output "alb_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "tg_arn" {
  value = module.alb.tg_arn
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "db_endpoint"  {
  value = module.rds.endpoint
}
