# Runbook

All commands run from `examples/complete` unless stated. Region is `eu-west-2`.

## 1. Verify for free (no AWS account)

```bash
terraform init -backend=false -input=false
terraform validate
terraform test          # mocked provider, no credentials
```

## 2. Deploy

```bash
cp terraform.tfvars.example terraform.tfvars   # edit as needed
terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output service_url
```

Tasks take 1-3 minutes to pass health checks. Until then the ALB returns 503.

Subscribe to alarms (when `create_alarm_topic = true`):

```bash
aws sns subscribe --topic-arn "$(terraform output -raw alarm_topic_arn)" \
  --protocol email --notification-endpoint you@example.com
```

## 3. Build and push the app/ image to ECR

```bash
REPO=$(terraform output -raw ecr_repository_url)
TAG=$(git rev-parse --short HEAD)

aws ecr get-login-password --region eu-west-2 \
  | docker login --username AWS --password-stdin "${REPO%%/*}"

# Fargate default is X86_64; build for it explicitly on Apple Silicon.
docker build --platform linux/amd64 -t "$REPO:$TAG" ../../app
docker push "$REPO:$TAG"

aws ecr describe-image-scan-findings --repository-name "${REPO##*/}" --image-id imageTag="$TAG"
```

Deploy it (tags are immutable, so every build needs a new tag):

```bash
terraform apply \
  -var "container_image=$REPO:$TAG" \
  -var "container_port=8080" \
  -var "container_user=101" \
  -var "readonly_root_filesystem=true" \
  -var 'writable_paths=["/tmp"]'
```

A pipeline version of this lives in [examples/deploy.yml](examples/deploy.yml).

## 4. Destroy

```bash
terraform destroy
```

The example sets `ecr_force_delete`, `log_bucket_force_destroy` and disables ALB deletion
protection so this completes in one pass. The KMS key enters a 7-day pending-deletion
window (no charge while pending).

## 5. Troubleshooting

| Symptom | Likely cause | Check |
|---|---|---|
| ALB returns 503 | No healthy targets yet, or tasks crash-looping | `aws ecs describe-services --cluster <c> --services <s> --query 'services[0].events[:5]'` |
| Tasks stop with `CannotPullContainerError` | No NAT route, or image tag does not exist | Private route table has `0.0.0.0/0 -> nat-*`; `aws ecr describe-images` |
| Tasks stop with `ResourceInitializationError: unable to pull secrets` | Secret ARN wrong or CMK not in `secrets_kms_key_arns` | Execution role policy, secret ARN in task definition |
| nginx exits with `Read-only file system` | Stock nginx with `readonly_root_filesystem = true` | Use the app/ image with `writable_paths = ["/tmp"]`, or set it to false |
| nginx exits with `bind() to 0.0.0.0:80 failed (13: Permission denied)` | Non-root user on port 80 | Use port 8080 with the app/ image |
| Deployment rolled back automatically | Circuit breaker tripped after repeated task failures | Service events, then `/ecs/<name>` log group |
| Target 5xx alarm | Application errors | `aws logs tail /ecs/<name> --follow` |
| Unhealthy hosts alarm | Health check path wrong or app slow to boot | `health_check_path`, `health_check_grace_period_seconds` |

Shell into a running task (requires `enable_execute_command = true`, Session Manager plugin installed):

```bash
TASK=$(aws ecs list-tasks --cluster "$(terraform output -raw cluster_name)" --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster "$(terraform output -raw cluster_name)" \
  --task "$TASK" --container app --interactive --command "/bin/sh"
```

Sessions are KMS-encrypted and transcripts go to `/ecs/<name>/exec`.
