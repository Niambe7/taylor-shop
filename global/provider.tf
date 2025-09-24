terraform {
required_version = ">= 1.7.0"
required_providers {
aws = {
source = "hashicorp/aws"
version = ">= 5.0"
}
random = {
source = "hashicorp/random"
version = ">= 3.5"
}
}
}


provider "aws" {
region = var.aws_region
default_tags = {
Project = "taylor-ticket-shop"
Environment = var.env
Owner = var.owner
}
}