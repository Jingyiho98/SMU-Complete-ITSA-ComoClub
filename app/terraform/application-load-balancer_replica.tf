module "alb_replica" {
  providers = {
    aws = aws.replica_region
  }
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"
  name    = "${var.namespace}-g2team8-alb"

  load_balancer_type = "application"

  vpc_id          = module.vpc_replica.vpc_id
  subnets         = module.vpc_replica.private_subnets
  security_groups = [aws_security_group.alb_sg_replica.id]
  internal        = true
  target_groups = [
    {
      name_prefix      = "mbrsn"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"
      health_check = {
        enabled  = true
        interval = 30
        path     = "/memberson/actuator/health"
        port     = 8080
        protocol = "HTTP"
      }
    },
    {
      name_prefix      = "svnrms"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"
      health_check = {
        enabled  = true
        interval = 30
        path     = "/sevenrooms/actuator/health"
        port     = 8080
        protocol = "HTTP"
      }
    },
    {
      name_prefix      = "stripe"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"
      health_check = {
        enabled  = true
        interval = 30
        path     = "/stripe/actuator/health"
        port     = 8080
        protocol = "HTTP"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port     = 80
      protocol = "HTTP"
    }
  ]
}

resource "aws_lb_listener_rule" "memberson_middleware_replica" {
  provider     = aws.replica_region
  listener_arn = module.alb_replica.http_tcp_listener_arns[0]

  action {
    type             = "forward"
    target_group_arn = module.alb_replica.target_group_arns[0]
  }

  condition {
    path_pattern {
      values = ["/memberson/*"]
    }
  }
}

resource "aws_lb_listener_rule" "sevenrooms_middleware_replica" {
  provider     = aws.replica_region
  listener_arn = module.alb_replica.http_tcp_listener_arns[0]

  action {
    type             = "forward"
    target_group_arn = module.alb_replica.target_group_arns[1]
  }

  condition {
    path_pattern {
      values = ["/sevenrooms/*"]
    }
  }
}

resource "aws_lb_listener_rule" "stripe_replica" {
  provider     = aws.replica_region
  listener_arn = module.alb_replica.http_tcp_listener_arns[0]

  action {
    type             = "forward"
    target_group_arn = module.alb_replica.target_group_arns[2]
  }

  condition {
    path_pattern {
      values = ["/stripe/*"]
    }
  }
}
