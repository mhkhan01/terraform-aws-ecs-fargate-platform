locals {
  # Each writable path becomes a task-scoped bind mount. Fargate has no tmpfs, so this is
  # how a read-only root filesystem coexists with software that writes pid/cache files.
  writable_volumes = {
    for p in var.writable_paths : "rw${replace(p, "/[^a-zA-Z0-9]/", "-")}" => p
  }

  container_definition = merge(
    {
      name      = var.container_name
      image     = var.container_image
      essential = true

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]

      readonlyRootFilesystem = var.readonly_root_filesystem
      privileged             = false

      environment = [for k, v in var.environment : { name = k, value = v }]
      secrets     = [for s in var.secrets : { name = s.name, valueFrom = s.value_from }]

      mountPoints = [for vname, path in local.writable_volumes : {
        sourceVolume  = vname
        containerPath = path
        readOnly      = false
      }]

      # Required for ECS Exec; harmless otherwise.
      linuxParameters = { initProcessEnabled = var.enable_execute_command }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = local.region
          awslogs-stream-prefix = var.container_name
        }
      }
    },
    # Omitting "user" falls back to the image default; only do that when the image requires it.
    var.container_user == null ? {} : { user = var.container_user },
  )
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "volume" {
    for_each = local.writable_volumes

    content {
      name = volume.key
    }
  }

  container_definitions = jsonencode([local.container_definition])

  tags = local.tags
}

resource "aws_ecs_service" "this" {
  name                    = local.name
  cluster                 = aws_ecs_cluster.this.id
  task_definition         = aws_ecs_task_definition.this.arn
  desired_count           = var.desired_count
  platform_version        = "LATEST"
  enable_execute_command  = var.enable_execute_command
  propagate_tags          = "SERVICE"
  enable_ecs_managed_tags = true

  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  # A deployment that never reaches steady state is rolled back automatically
  # instead of looping on failing tasks.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "capacity_provider_strategy" {
    for_each = local.capacity_provider_strategy

    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  tags = local.tags

  # Auto scaling owns desired_count after the first apply.
  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this, aws_iam_role_policy.execution]
}
