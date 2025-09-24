variable "vpc_id"            { type = string }
variable "subnet_ids"        { type = list(string) }
variable "security_group_id" { type = string }

resource "aws_efs_file_system" "this" {
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = { Name = "ps-efs" }
}

#  Clés statiques (0,1,2) => valeurs potentiellement inconnues (IDs)
locals {
  subnet_map = { for idx, subnet_id in var.subnet_ids : idx => subnet_id }
}

resource "aws_efs_mount_target" "mt" {
  for_each        = local.subnet_map
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [var.security_group_id]
}

output "efs_id" {
  value = aws_efs_file_system.this.id
}
