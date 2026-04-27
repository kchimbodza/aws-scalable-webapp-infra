# IAM Instance Profile
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_iam_instance_profile" "lab_role" {
  name = "webapp-lab-instance-profile"
  role = data.aws_iam_role.lab_role.name
}

# Launch Template
resource "aws_launch_template" "webapp" {
  name_prefix   = "webapp-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.lab_role.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.webapp_ec2.id]
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    db_host     = aws_db_instance.webapp.address
    db_port     = aws_db_instance.webapp.port
    db_username = var.db_username
    db_password = var.db_password
    db_name     = var.db_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "webapp-asg-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
