# ecs-service

ECS Fargate service with its own image registry, encryption key, IAM roles, scaling and alarms.

- ECR repository: scan on push, immutable tags, KMS encryption, lifecycle policy that keeps the last N images.
- Cluster with Container Insights and both `FARGATE` and `FARGATE_SPOT` capacity providers (configurable weights and on-demand base).
- Task definition: `awsvpc`, validated Fargate CPU/memory pairs, read-only root filesystem and non-root user by default, KMS-encrypted CloudWatch logs, secrets by SSM / Secrets Manager ARN.
- Separate execution role (pull, logs, secrets) and task role (application, plus ECS Exec when enabled).
- Service in private subnets with deployment circuit breaker and rollback, health check grace period and an ECS Exec toggle.
- Application Auto Scaling target tracking on CPU and on ALB `RequestCountPerTarget`.
- CloudWatch alarms on target 5xx, unhealthy hosts and high CPU, with an optional KMS-encrypted SNS topic.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.requests](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.cpu_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.target_5xx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.unhealthy_hosts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.task_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_sns_topic.alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ecs_tasks_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_5xx_threshold"></a> [alarm\_5xx\_threshold](#input\_alarm\_5xx\_threshold) | Target 5xx responses per minute that count as a breach. | `number` | `10` | no |
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | Extra ARNs (for example an existing SNS topic) notified on alarm and OK transitions. | `list(string)` | `[]` | no |
| <a name="input_alarm_cpu_threshold"></a> [alarm\_cpu\_threshold](#input\_alarm\_cpu\_threshold) | Average service CPU (%) that counts as a breach. | `number` | `85` | no |
| <a name="input_alb_arn_suffix"></a> [alb\_arn\_suffix](#input\_alb\_arn\_suffix) | ALB ARN suffix, used for RequestCountPerTarget scaling and ALB alarms. | `string` | n/a | yes |
| <a name="input_autoscaling_cpu_target"></a> [autoscaling\_cpu\_target](#input\_autoscaling\_cpu\_target) | Target average CPU utilisation (%) for the CPU policy. | `number` | `60` | no |
| <a name="input_autoscaling_max_capacity"></a> [autoscaling\_max\_capacity](#input\_autoscaling\_max\_capacity) | Maximum number of tasks; also the cost ceiling. | `number` | `6` | no |
| <a name="input_autoscaling_min_capacity"></a> [autoscaling\_min\_capacity](#input\_autoscaling\_min\_capacity) | Minimum number of tasks. | `number` | `2` | no |
| <a name="input_autoscaling_requests_per_target"></a> [autoscaling\_requests\_per\_target](#input\_autoscaling\_requests\_per\_target) | Target ALB requests per task per minute for the request-count policy. | `number` | `1000` | no |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Full image reference, e.g. an ECR URI with an immutable tag or a public.ecr.aws image. | `string` | n/a | yes |
| <a name="input_container_insights"></a> [container\_insights](#input\_container\_insights) | Container Insights mode: enhanced, enabled or disabled. | `string` | `"enabled"` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the container inside the task definition. | `string` | `"app"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Port the container listens on. | `number` | `80` | no |
| <a name="input_container_user"></a> [container\_user](#input\_container\_user) | UID[:GID] the container runs as. Defaults to a non-root user; set null only for images that cannot run unprivileged. | `string` | `"1000:1000"` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Task CPU units. Must be a Fargate size: 256, 512, 1024, 2048, 4096, 8192 or 16384. | `number` | `256` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | X86\_64 or ARM64. ARM64 (Graviton) is about 20% cheaper but cannot use Fargate Spot. | `string` | `"X86_64"` | no |
| <a name="input_create_alarm_topic"></a> [create\_alarm\_topic](#input\_create\_alarm\_topic) | Create a KMS-encrypted SNS topic and wire every alarm to it. Subscribe to it after apply. | `bool` | `false` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Upper bound of running tasks during a deployment, as a percentage of desired\_count. | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | Lower bound of running tasks during a deployment, as a percentage of desired\_count. | `number` | `100` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Initial number of tasks. Auto scaling takes over afterwards when enabled. | `number` | `2` | no |
| <a name="input_ecr_force_delete"></a> [ecr\_force\_delete](#input\_ecr\_force\_delete) | Allow destroying the ECR repository while it still holds images. Demo convenience only. | `bool` | `false` | no |
| <a name="input_ecr_keep_last_images"></a> [ecr\_keep\_last\_images](#input\_ecr\_keep\_last\_images) | Number of images the ECR lifecycle policy keeps; older ones are expired. | `number` | `20` | no |
| <a name="input_enable_alarms"></a> [enable\_alarms](#input\_enable\_alarms) | Create CloudWatch alarms for target 5xx, unhealthy hosts and high CPU. | `bool` | `true` | no |
| <a name="input_enable_autoscaling"></a> [enable\_autoscaling](#input\_enable\_autoscaling) | Create Application Auto Scaling target-tracking policies on CPU and ALB requests per target. | `bool` | `true` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | Allow `aws ecs execute-command` into running tasks. Sessions are KMS-encrypted and logged. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Plain-text environment variables. Never put secrets here; use secrets instead. | `map(string)` | `{}` | no |
| <a name="input_fargate_base"></a> [fargate\_base](#input\_fargate\_base) | Tasks always placed on on-demand FARGATE before weights apply, so Spot interruptions never take the service to zero. | `number` | `1` | no |
| <a name="input_fargate_spot_weight"></a> [fargate\_spot\_weight](#input\_fargate\_spot\_weight) | Relative share of tasks placed on FARGATE\_SPOT (up to ~70% cheaper, can be interrupted with 2 minutes notice). | `number` | `0` | no |
| <a name="input_fargate_weight"></a> [fargate\_weight](#input\_fargate\_weight) | Relative share of tasks placed on on-demand FARGATE. | `number` | `1` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Seconds ECS ignores ALB health checks after a task starts, covering slow application boot. | `number` | `60` | no |
| <a name="input_kms_deletion_window_in_days"></a> [kms\_deletion\_window\_in\_days](#input\_kms\_deletion\_window\_in\_days) | Waiting period before the service KMS key is deleted after destroy. | `number` | `7` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention for application and ECS Exec logs. | `number` | `30` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Task memory in MiB. Must be a valid Fargate pairing for the chosen cpu. | `number` | `512` | no |
| <a name="input_name"></a> [name](#input\_name) | Name used for the cluster, service, task family, ECR repository and log groups. | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnets the tasks run in. Tasks never get public IPs. | `list(string)` | n/a | yes |
| <a name="input_readonly_root_filesystem"></a> [readonly\_root\_filesystem](#input\_readonly\_root\_filesystem) | Mount the container root filesystem read-only. Pair with writable\_paths for software that needs scratch space. | `bool` | `true` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Secrets injected as environment variables at start-up. value\_from must be an SSM Parameter Store or Secrets Manager ARN. | <pre>list(object({<br/>    name       = string<br/>    value_from = string<br/>  }))</pre> | `[]` | no |
| <a name="input_secrets_kms_key_arns"></a> [secrets\_kms\_key\_arns](#input\_secrets\_kms\_key\_arns) | Customer managed KMS keys that encrypt the referenced secrets, if not the AWS managed default. | `list(string)` | `[]` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security groups attached to the task ENIs (normally the service SG from the alb module). | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags merged onto every resource. | `map(string)` | `{}` | no |
| <a name="input_target_group_arn"></a> [target\_group\_arn](#input\_target\_group\_arn) | ALB target group (type ip) the service registers tasks into. | `string` | n/a | yes |
| <a name="input_target_group_arn_suffix"></a> [target\_group\_arn\_suffix](#input\_target\_group\_arn\_suffix) | Target group ARN suffix, used for RequestCountPerTarget scaling and ALB alarms. | `string` | n/a | yes |
| <a name="input_task_role_policy_arns"></a> [task\_role\_policy\_arns](#input\_task\_role\_policy\_arns) | IAM policies to attach to the task (application) role, keyed by a static name. | `map(string)` | `{}` | no |
| <a name="input_writable_paths"></a> [writable\_paths](#input\_writable\_paths) | Container paths that get a task-scoped writable volume (for example /tmp) so a read-only root filesystem still works. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alarm_names"></a> [alarm\_names](#output\_alarm\_names) | Names of the CloudWatch alarms created. |
| <a name="output_alarm_topic_arn"></a> [alarm\_topic\_arn](#output\_alarm\_topic\_arn) | ARN of the alarm SNS topic, or null when create\_alarm\_topic is false. |
| <a name="output_autoscaling_policy_names"></a> [autoscaling\_policy\_names](#output\_autoscaling\_policy\_names) | Names of the target-tracking scaling policies (empty when auto scaling is disabled). |
| <a name="output_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#output\_capacity\_provider\_strategy) | Capacity provider weights and base applied to the service. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the ECS cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster. |
| <a name="output_container_definition"></a> [container\_definition](#output\_container\_definition) | The rendered container definition, useful for review and tests. |
| <a name="output_ecr_repository_arn"></a> [ecr\_repository\_arn](#output\_ecr\_repository\_arn) | ARN of the ECR repository. |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | URL to tag and push images to. |
| <a name="output_execute_command_enabled"></a> [execute\_command\_enabled](#output\_execute\_command\_enabled) | Whether ECS Exec is enabled on the service. |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ARN of the task execution role (ECS agent). |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the customer managed key used for ECR, logs, ECS Exec and SNS. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | CloudWatch log group receiving container stdout/stderr. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the ECS service. |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | Task definition family; each apply with a new image registers a new revision. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ARN of the task role (application code). |
| <a name="output_task_size"></a> [task\_size](#output\_task\_size) | Task CPU units and memory (MiB). |
<!-- END_TF_DOCS -->
