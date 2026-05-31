data "aws_instances" "eb" {
  filter {
    name   = "tag:elasticbeanstalk:environment-name"
    values = ["finpay-production"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_elastic_beanstalk_environment.finpay_production]
}

resource "aws_lb_target_group_attachment" "eb" {
  for_each         = toset(data.aws_instances.eb.ids)
  target_group_arn = aws_lb_target_group.finpay.arn
  target_id        = each.value
  port             = 3000
}
