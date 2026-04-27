# DB Subnet Group
resource "aws_db_subnet_group" "webapp" {
  name       = "webapp-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "webapp-db-subnet-group"
  }
}

# Parameter Group
resource "aws_db_parameter_group" "webapp" {
  name   = "webapp-mysql8-params"
  family = "mysql8.0"

  parameter {
    name         = "require_secure_transport"
    value        = "0"
    apply_method = "immediate"
  }

  tags = {
    Name = "webapp-mysql8-params"
  }
}

# RDS Instance
resource "aws_db_instance" "webapp" {
  identifier        = "webapp-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  db_name           = var.db_name
  username          = var.db_username
  password          = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.webapp.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  allocated_storage    = 20
  storage_type         = "gp2"
  storage_encrypted    = true

  parameter_group_name    = aws_db_parameter_group.webapp.name
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0
  multi_az                = false

  tags = {
    Name = "webapp-db"
  }
}
