resource "aws_db_subnet_group" "this" {
name = "ps-db-subnet-group"
subnet_ids = var.subnet_ids
}


resource "aws_db_instance" "this" {
identifier = "ps-mysql"
engine = "mysql"
engine_version = "8.0"
instance_class = var.instance_class
storage_type = "gp2"
allocated_storage = 20
db_name = var.db_name
username = var.username
password = var.password
skip_final_snapshot = true
multi_az = var.multi_az
publicly_accessible = false 
vpc_security_group_ids = var.vpc_security_group_ids
db_subnet_group_name = aws_db_subnet_group.this.name
}


output "endpoint" { value = aws_db_instance.this.address }