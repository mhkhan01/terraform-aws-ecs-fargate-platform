################################################################################
# Two roles, deliberately separate:
#   execution role - used by the ECS agent to pull the image, write logs and inject secrets
#   task role      - assumed by the application code itself at runtime
# Keeping them apart means a compromised container cannot read every secret the task was
# launched with, nor pull arbitrary images.
################################################################################

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # Confused-deputy protection: only tasks in this account can assume the roles.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
    }
  }
}

################################################################################
# Execution role
################################################################################

resource "aws_iam_role" "execution" {
  name_prefix        = substr("${local.name}-exec-", 0, 38)
  description        = "ECS agent role for ${local.name}: image pull, logs, secret injection"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = local.tags
}

data "aws_iam_policy_document" "execution" {
  # GetAuthorizationToken is account-level and does not support resource scoping.
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [aws_ecr_repository.this.arn]
  }

  statement {
    sid       = "WriteAppLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }

  # Image layers are encrypted with the CMK; secrets may be too.
  statement {
    sid       = "DecryptWithServiceKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.this.arn]
  }

  dynamic "statement" {
    for_each = length(local.ssm_secret_arns) > 0 ? [1] : []

    content {
      sid       = "ReadSSMParameters"
      effect    = "Allow"
      actions   = ["ssm:GetParameters"]
      resources = local.ssm_secret_arns
    }
  }

  dynamic "statement" {
    for_each = length(local.sm_secret_arns) > 0 ? [1] : []

    content {
      sid       = "ReadSecretsManager"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = local.sm_secret_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.secrets_kms_key_arns) > 0 ? [1] : []

    content {
      sid       = "DecryptSecretKeys"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.secrets_kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

################################################################################
# Task role
################################################################################

resource "aws_iam_role" "task" {
  name_prefix        = substr("${local.name}-task-", 0, 38)
  description        = "Application role for ${local.name} containers"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = local.tags
}

data "aws_iam_policy_document" "exec" {
  count = var.enable_execute_command ? 1 : 0

  # The SSM agent inside the task opens channels before any session ID exists,
  # so these actions cannot be scoped to a resource.
  statement {
    sid    = "ECSExecChannels"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ECSExecLogging"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.exec[0].arn}:*"]
  }

  # DescribeLogGroups is list-level and has no resource-level permissions.
  statement {
    sid       = "ECSExecDescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ECSExecKMS"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.this.arn]
  }
}

resource "aws_iam_role_policy" "exec" {
  count = var.enable_execute_command ? 1 : 0

  name   = "ecs-exec"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.exec[0].json
}

# Map keys (not ARNs) drive for_each so policies created in the same apply still plan cleanly.
resource "aws_iam_role_policy_attachment" "task_extra" {
  for_each = var.task_role_policy_arns

  role       = aws_iam_role.task.name
  policy_arn = each.value
}
