# -------- User data (template) --------
locals {
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    region                 = var.region
    db_password_param_name = var.db_password_param_name
    db_endpoint            = var.db_endpoint
    db_name                = var.db_name
    db_user                = var.db_user
    efs_id                 = var.efs_id
    prestashop_image_tag   = var.prestashop_image_tag
    alb_dns_name           = var.alb_dns_name
  })
}

# -------- AMI Amazon Linux 2 --------
data "aws_ami" "al2" {
  owners      = ["137112412989"] # Amazon
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -------- Launch Template --------
resource "aws_launch_template" "lt" {
  name_prefix   = "ps-lt-"
  image_id      = data.aws_ami.al2.id
  instance_type = "t3.small"

  iam_instance_profile { name = var.instance_profile_name }

  network_interfaces {
    security_groups             = [var.security_group_id]
    associate_public_ip_address = false
  }

  user_data = base64encode(local.user_data)
}

# -------- AutoScaling Group --------
resource "aws_autoscaling_group" "asg" {
  name                      = "ps-asg"
  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 3
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -------- Attachement à l'ALB Target Group --------
resource "aws_autoscaling_attachment" "alb_tg" {
  autoscaling_group_name = aws_autoscaling_group.asg.name
  lb_target_group_arn    = var.alb_tg_arn  # <-- juste ce nom d'attribut qui change
}
