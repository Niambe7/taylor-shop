variable "name"               { type = string }
variable "subnet_ids"         { type = list(string) }
variable "security_group_id"  { type = string }
variable "vpc_id"             { type = string }

resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]
}

resource "aws_lb_target_group" "tg" {
  name     = "ps-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id


health_check {
  path                = "/"
  matcher             = "200-399"
  interval            = 30
  timeout             = 5
  healthy_threshold   = 3
  unhealthy_threshold = 3
}


  # Si tu veux matcher 200-399 plus tard :
  # matcher { http_code = "200-399" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "alb_dns_name" { value = aws_lb.this.dns_name }
output "tg_arn"       { value = aws_lb_target_group.tg.arn }
