locals {
  name       = var.name
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition

  tags = merge(var.tags, { Module = "ecs-service" })

  log_group_name      = "/ecs/${local.name}"
  exec_log_group_name = "/ecs/${local.name}/exec"

  ssm_secret_arns = [for s in var.secrets : s.value_from if can(regex("^arn:aws[a-z-]*:ssm:", s.value_from))]
  sm_secret_arns  = [for s in var.secrets : s.value_from if can(regex("^arn:aws[a-z-]*:secretsmanager:", s.value_from))]

  # Fargate Spot is a separate capacity provider; a weight of 0 means it is registered
  # on the cluster but receives no tasks.
  capacity_provider_strategy = [
    { capacity_provider = "FARGATE", weight = var.fargate_weight, base = var.fargate_base },
    { capacity_provider = "FARGATE_SPOT", weight = var.fargate_spot_weight, base = 0 },
  ]
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

################################################################################
# KMS: one customer managed key for ECR images, CloudWatch logs, ECS Exec and SNS
################################################################################

data "aws_iam_policy_document" "kms" {
  # Key policies are attached to a single key, so Resource "*" here means "this key".
  statement {
    sid       = "AccountAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid    = "CloudWatchLogsUse"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${local.log_group_name}*"]
    }
  }

  # CloudWatch alarms publishing to a KMS-encrypted SNS topic need this explicitly.
  statement {
    sid       = "CloudWatchAlarmsToSNS"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "Encrypts ECR images, logs, ECS Exec sessions and alarm notifications for ${local.name}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json

  tags = merge(local.tags, { Name = "${local.name}-ecs" })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name}-ecs"
  target_key_id = aws_kms_key.this.key_id
}

################################################################################
# ECR
################################################################################

resource "aws_ecr_repository" "this" {
  name                 = local.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.this.arn
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last ${var.ecr_keep_last_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_keep_last_images
        }
        action = { type = "expire" }
      },
    ]
  })
}

################################################################################
# Logs
################################################################################

resource "aws_cloudwatch_log_group" "app" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.this.arn

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "exec" {
  count = var.enable_execute_command ? 1 : 0

  name              = local.exec_log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.this.arn

  tags = local.tags
}

################################################################################
# Cluster
################################################################################

resource "aws_ecs_cluster" "this" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  # ECS Exec sessions are encrypted with the CMK and transcripts land in CloudWatch,
  # so interactive access is auditable.
  dynamic "configuration" {
    for_each = var.enable_execute_command ? [1] : []

    content {
      execute_command_configuration {
        kms_key_id = aws_kms_key.this.arn
        logging    = "OVERRIDE"

        log_configuration {
          cloud_watch_encryption_enabled = true
          cloud_watch_log_group_name     = aws_cloudwatch_log_group.exec[0].name
        }
      }
    }
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  dynamic "default_capacity_provider_strategy" {
    for_each = local.capacity_provider_strategy

    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}
