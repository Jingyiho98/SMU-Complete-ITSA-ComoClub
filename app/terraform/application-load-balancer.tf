module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"
  name    = "${var.namespace}-g2team8-alb"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.private_subnets
  security_groups = [aws_security_group.alb_sg.id]
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

resource "aws_lb_listener_rule" "memberson_middleware" {
  listener_arn = module.alb.http_tcp_listener_arns[0]

  action {
    type             = "forward"
    target_group_arn = module.alb.target_group_arns[0]
  }

  condition {
    path_pattern {
      values = ["/memberson/*"]
    }
  }
}

resource "aws_lb_listener_rule" "sevenrooms_middleware" {
  listener_arn = module.alb.http_tcp_listener_arns[0]

  action {
    type             = "forward"
    target_group_arn = module.alb.target_group_arns[1]
  }

  condition {
    path_pattern {
      values = ["/sevenrooms/*"]
    }
  }
}

resource "aws_lb_listener_rule" "stripe" {
  listener_arn = module.alb.http_tcp_listener_arns[0]

  action {
    type             = "forward"
    target_group_arn = module.alb.target_group_arns[2]
  }

  condition {
    path_pattern {
      values = ["/stripe/*"]
    }
  }
}
