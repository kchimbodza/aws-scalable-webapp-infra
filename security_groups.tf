# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "webapp-alb-sg"
  description = "Allow HTTP inbound from anywhere"
  vpc_id      = aws_vpc.webapp.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webapp-alb-sg"
  }
}

# EC2 Security Group
resource "aws_security_group" "webapp_ec2" {
  name        = "webapp-ec2-sg"
  description = "Allow port 8080 from ALB only"
  vpc_id      = aws_vpc.webapp.id

  ingress {
    description     = "HTTP 8080 from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webapp-ec2-sg"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "webapp-rds-sg"
  description = "Allow MySQL 3306 from EC2 only"
  vpc_id      = aws_vpc.webapp.id

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.webapp_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webapp-rds-sg"
  }
}
