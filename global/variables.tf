variable "aws_region" {
description = "AWS region"
type = string
default = "eu-west-3"
}


variable "env" {
description = "Environment name (dev|staging|prod)"
type = string
}


variable "owner" {
description = "Owner / team name"
type = string
default = "platform-team"
}