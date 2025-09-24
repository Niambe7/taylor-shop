variable "region" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "alb_tg_arn" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password_param_name" {
  type = string
}

variable "efs_id" {
  type = string
}

variable "prestashop_image_tag" {
  type    = string
  default = "latest"
}

variable "alb_dns_name" {
  type = string
}
