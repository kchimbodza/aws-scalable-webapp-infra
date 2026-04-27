variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "webapp_admin"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "webapp_db"
}

variable "ami_id" {
  description = "AMI ID for the web application"
  type        = string
  default = "ami-03a6c16a66bbe0a7a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
