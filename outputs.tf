output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.webapp.id
}

output "alb_dns_name" {
  description = "ALB DNS name - use this for API testing"
  value       = aws_lb.webapp.dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.webapp.address
  sensitive   = true
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.webapp.name
}
