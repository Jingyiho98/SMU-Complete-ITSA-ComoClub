resource "aws_service_discovery_service" "memberson_middleware_replica" {
  provider     = aws.replica_region
  name         = "memberson_middleware"
  namespace_id = aws_service_discovery_private_dns_namespace.g2team8_replica.id

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.g2team8_replica.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "memberson_middleware_replica" {
  provider = aws.replica_region
  name     = "memberson_middleware"
  cluster  = aws_ecs_cluster.g2team8_cluster_replica.id

  task_definition = aws_ecs_task_definition.memberson_middleware_replica.arn

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  service_registries {
    registry_arn = aws_service_discovery_service.memberson_middleware_replica.arn
  }

  load_balancer {
    target_group_arn = module.alb_replica.target_group_arns[0]
    container_name   = "memberson_middleware"
    container_port   = 8080
  }

  network_configuration {
    security_groups  = [aws_security_group.cluster_entry_replica.id]
    subnets          = module.vpc_replica.private_subnets
    assign_public_ip = false
  }

  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"


  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
  depends_on = [
    aws_iam_role_policy.task,
    aws_iam_role_policy.execution
  ]
}

// Using this as a wrapper for the cloudposse version ref to online
resource "aws_ecs_task_definition" "memberson_middleware_replica" {
  provider = aws.replica_region
  family   = "memberson_middleware"

  network_mode       = "awsvpc"
  task_role_arn      = aws_iam_role.task_role.arn
  execution_role_arn = aws_iam_role.execution_role.arn
  cpu                = "256"
  memory             = "512"

  container_definitions = <<-EOF
[
  ${module.ecs_container_definition_memberson_middleware_replica.json_map_encoded}
]
EOF

  requires_compatibilities = ["FARGATE"]

  // This wull be updated by CI/CD
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

module "ecs_container_definition_memberson_middleware_replica" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_name  = "memberson_middleware"
  container_image = "${data.aws_ecr_repository.ecr_memberson_replica.repository_url}:latest"

  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.g2team8_replica.name
      awslogs-region        = var.replica_region
      awslogs-stream-prefix = "ecs-api"
    }
  }

  essential = true

  port_mappings = [
    {
      hostPort      = 8080
      containerPort = 8080
      protocol      = "tcp"
    }
  ]

  environment = [
    {
      name  = "amazon.aws.accesskey"
      value = var.aws_keys.accesskey
    },
    {
      name  = "amazon.aws.secretkey"
      value = var.aws_keys.secretkey
    }
  ]
  secrets = []
}


resource "aws_appautoscaling_target" "memberson_middleware_autoscaling_replica" {
  provider     = aws.replica_region
  min_capacity = 1
  max_capacity = 4

  resource_id = "service/${aws_ecs_cluster.g2team8_cluster_replica.name}/${aws_ecs_service.memberson_middleware_replica.name}"

  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "memberson_middleware_autoscaling_policy_replica" {
  provider    = aws.replica_region
  name        = "memberson_middleware_autoscale"
  policy_type = "TargetTrackingScaling"

  resource_id        = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.resource_id
  scalable_dimension = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.scalable_dimension
  service_namespace  = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${module.alb_replica.lb_arn_suffix}/${module.alb_replica.target_group_arn_suffixes[0]}"
    }

    target_value       = 50
    scale_in_cooldown  = 400
    scale_out_cooldown = 200
    disable_scale_in   = true
  }
}

# resource "aws_appautoscaling_policy" "memberson_middleware_autoscaling_policy_memory_replica" {
#   provider           = aws.replica_region
#   name               = "memberson_middleware_autoscale_memory"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.resource_id
#   scalable_dimension = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageMemoryUtilization"
#     }

#     target_value       = 85
#     scale_in_cooldown  = 400
#     scale_out_cooldown = 200
#     disable_scale_in   = true
#   }
# }

resource "aws_appautoscaling_policy" "memberson_middleware_autoscaling_policy_cpu_replica" {
  provider           = aws.replica_region
  name               = "memberson_middleware_autoscale_cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.resource_id
  scalable_dimension = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.scalable_dimension
  service_namespace  = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60
    scale_in_cooldown  = 400
    scale_out_cooldown = 200
    disable_scale_in   = true
  }
}

# # Commented out to save cost.
# resource "aws_appautoscaling_scheduled_action" "memberson_middleware_autoscaling_scheduled_replica" {
#   provider           = aws.replica_region
#   name               = "memberson_middleware_autoscale_scheduled"
#   service_namespace  = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.service_namespace
#   resource_id        = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.resource_id
#   scalable_dimension = aws_appautoscaling_target.memberson_middleware_autoscaling_replica.scalable_dimension
#   schedule           = "cron(30 17 * * ? *)"
#   timezone           = "Asia/Singapore"

#   scalable_target_action {
#     min_capacity = 4
#     max_capacity = 6
#   }
# }
