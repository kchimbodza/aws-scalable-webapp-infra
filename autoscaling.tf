# Auto Scaling Group
resource "aws_autoscaling_group" "webapp" {
  name                      = "webapp-asg"
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  health_check_type         = "ELB"
  health_check_grace_period = 120
  vpc_zone_identifier       = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.webapp.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.webapp.arn]

  tag {
    key                 = "Name"
    value               = "webapp-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Scale Up Policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "webapp-scale-up"
  autoscaling_group_name = aws_autoscaling_group.webapp.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
  policy_type            = "SimpleScaling"
}

# Scale Down Policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "webapp-scale-down"
  autoscaling_group_name = aws_autoscaling_group.webapp.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
  policy_type            = "SimpleScaling"
}

# CloudWatch Alarm - High CPU
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "webapp-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale up when CPU > 70%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

# CloudWatch Alarm - Low CPU
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "webapp-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale down when CPU < 30%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}
