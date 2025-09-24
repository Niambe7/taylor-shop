variable "name" { type = string }
variable "cidr" { type = string }
variable "azs"  { type = list(string) }

variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_cidrs"   { type = list(string) }
variable "private_db_cidrs"    { type = list(string) }

variable "single_nat_gateway" {
  description = "true = 1 NAT (eco) ; false = 1 NAT par AZ"
  type        = bool
  default     = true
}
