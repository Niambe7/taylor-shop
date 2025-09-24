variable "db_password_param_name" { type = string }


resource "aws_iam_role" "ec2_role" {
name = "ec2-prestashop-role"
assume_role_policy = jsonencode({
Version = "2012-10-17"
Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
})
}


resource "aws_iam_role_policy_attachment" "ssm_core" {
role = aws_iam_role.ec2_role.name
policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_policy" "ssm_read_param" {
name = "ec2-ssm-read-dbpass"
policy = jsonencode({
Version = "2012-10-17",
Statement = [{
Effect = "Allow",
Action = ["ssm:GetParameter"],
Resource = "arn:aws:ssm:*:*:parameter${var.db_password_param_name}"
}]
})
}


resource "aws_iam_role_policy_attachment" "attach_read_param" {
role = aws_iam_role.ec2_role.name
policy_arn = aws_iam_policy.ssm_read_param.arn
}


resource "aws_iam_instance_profile" "ec2_profile" {
name = "ec2-prestashop-profile"
role = aws_iam_role.ec2_role.name
}


output "instance_profile_name" { value = aws_iam_instance_profile.ec2_profile.name }