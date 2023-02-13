module "nlb_replica" {
  providers = {
    aws = aws.replica_region
  }
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"
  name    = "${var.namespace}-g2team8-nlb"

  load_balancer_type = "network"

  vpc_id   = module.vpc_replica.vpc_id
  subnets  = module.vpc_replica.private_subnets
  internal = true
  target_groups = [
    {
      name_prefix      = "alb"
      backend_protocol = "TCP"
      backend_port     = 80
      target_type      = "alb"
      health_check = {
        enabled  = true
        interval = 30
        path     = "/sevenrooms/actuator/health"
        protocol = "HTTP"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port     = 80
      protocol = "TCP"
    }
  ]
}

resource "aws_lb_target_group_attachment" "alb_target_replica" {
  provider         = aws.replica_region
  target_group_arn = module.nlb_replica.target_group_arns[0]
  target_id        = module.alb_replica.lb_id
  port             = 80
}
