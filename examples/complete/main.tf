locals {
  name = "${var.name}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name     = local.name
  vpc_cidr = var.vpc_cidr
}

module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  container_port    = var.container_port
  allowed_cidrs     = var.allowed_cidrs
  health_check_path = var.health_check_path

  # null keeps the demo usable without a domain: port 80 forwards straight to the tasks.
  certificate_arn = var.certificate_arn
  enable_waf      = var.enable_waf

  # Demo settings so `terraform destroy` succeeds in one go; keep the module defaults in production.
  enable_deletion_protection = var.enable_deletion_protection
  log_bucket_force_destroy   = true
}

module "ecs_service" {
  source = "../../modules/ecs-service"

  name                    = local.name
  private_subnet_ids      = module.network.private_subnet_ids
  security_group_ids      = [module.alb.service_security_group_id]
  target_group_arn        = module.alb.target_group_arn
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  container_image = var.container_image
  container_port  = var.container_port
  cpu             = var.cpu
  memory          = var.memory

  # The stock nginx image starts its master process as root to bind :80 and writes
  # pid/cache files under /var, so it cannot run read-only or unprivileged as-is.
  # The image in app/ (nginx-unprivileged on 8080, UID 101) is the hardened path:
  #   container_user = "101", readonly_root_filesystem = true, writable_paths = ["/tmp"]
  container_user           = var.container_user
  readonly_root_filesystem = var.readonly_root_filesystem
  writable_paths           = var.writable_paths

  desired_count            = var.desired_count
  autoscaling_min_capacity = var.autoscaling_min_capacity
  autoscaling_max_capacity = var.autoscaling_max_capacity

  fargate_weight      = var.fargate_weight
  fargate_spot_weight = var.fargate_spot_weight

  enable_execute_command = var.enable_execute_command
  create_alarm_topic     = var.create_alarm_topic
  secrets                = var.secrets

  ecr_force_delete = true
}
