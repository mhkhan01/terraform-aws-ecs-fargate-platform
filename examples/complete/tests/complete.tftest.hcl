# Offline tests: every run uses a mocked AWS provider, so no credentials or spend are needed.
# Run from examples/complete: terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "eu-west-2"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }

  # Regional ELB log-delivery account for eu-west-2.
  mock_data "aws_elb_service_account" {
    defaults = {
      arn = "arn:aws:iam::652711504416:root"
    }
  }
}

run "defaults_http_demo_mode" {
  command = plan

  assert {
    condition     = output.public_subnet_cidrs == ["10.0.0.0/24", "10.0.1.0/24"]
    error_message = "Public subnets should be the first two /24s of the VPC."
  }

  assert {
    condition     = output.private_subnet_cidrs == ["10.0.10.0/24", "10.0.11.0/24"]
    error_message = "Private subnets should start at netnum 10."
  }

  assert {
    condition     = output.availability_zones == tolist(["eu-west-2a", "eu-west-2b"])
    error_message = "Exactly two AZs should be used by default."
  }

  assert {
    condition     = output.nat_gateway_count == 1
    error_message = "A single NAT gateway is expected."
  }

  assert {
    condition     = output.http_listener_action == "forward" && output.https_enabled == false
    error_message = "Without a certificate, port 80 must forward and no HTTPS listener should exist."
  }

  assert {
    condition     = output.https_ingress_rule_count == 0
    error_message = "443 should not be opened when HTTPS is disabled."
  }

  assert {
    condition     = output.waf_enabled == false
    error_message = "WAF is off by default."
  }

  assert {
    condition     = output.access_log_bucket == "webapp-dev-alb-logs-123456789012"
    error_message = "Log bucket name should combine the prefix and account ID."
  }

  assert {
    condition     = output.cluster_name == "webapp-dev" && output.log_group_name == "/ecs/webapp-dev"
    error_message = "Cluster and log group should follow the name-environment convention."
  }

  assert {
    condition     = length(output.autoscaling_policy_names) == 2
    error_message = "CPU and RequestCountPerTarget policies should both exist."
  }

  assert {
    condition     = length(output.alarm_names) == 3
    error_message = "5xx, unhealthy-host and CPU alarms should exist."
  }

  assert {
    condition     = output.execute_command_enabled == false
    error_message = "ECS Exec should be off by default."
  }
}

run "container_definition_hardening" {
  command = plan

  variables {
    container_image          = "123456789012.dkr.ecr.eu-west-2.amazonaws.com/webapp-dev:3f2c1ab"
    container_port           = 8080
    container_user           = "101"
    readonly_root_filesystem = true
    writable_paths           = ["/tmp"]
    secrets = [
      { name = "DB_PASSWORD", value_from = "arn:aws:ssm:eu-west-2:123456789012:parameter/webapp/dev/db-password" },
    ]
  }

  assert {
    condition     = output.container_definition.readonlyRootFilesystem == true
    error_message = "Root filesystem should be read-only."
  }

  assert {
    condition     = output.container_definition.user == "101"
    error_message = "Container should run as the non-root UID supplied."
  }

  assert {
    condition     = output.container_definition.mountPoints[0].containerPath == "/tmp"
    error_message = "/tmp should be mounted writable."
  }

  assert {
    condition     = output.container_definition.secrets[0].valueFrom == "arn:aws:ssm:eu-west-2:123456789012:parameter/webapp/dev/db-password"
    error_message = "Secrets should be passed by ARN, never by value."
  }

  assert {
    condition     = output.container_definition.logConfiguration.options["awslogs-region"] == "eu-west-2"
    error_message = "Logs should ship to the provider region."
  }

  assert {
    condition     = output.container_definition.portMappings[0].containerPort == 8080
    error_message = "Port mapping should follow container_port."
  }
}

run "https_waf_exec_enabled" {
  command = plan

  variables {
    certificate_arn        = "arn:aws:acm:eu-west-2:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    enable_waf             = true
    enable_execute_command = true
    allowed_cidrs          = ["203.0.113.0/24", "198.51.100.0/24"]
  }

  assert {
    condition     = output.http_listener_action == "redirect"
    error_message = "With a certificate, port 80 must redirect to HTTPS."
  }

  assert {
    condition     = output.https_enabled == true
    error_message = "An HTTPS listener should exist when a certificate is supplied."
  }

  assert {
    condition     = output.https_ingress_rule_count == 2
    error_message = "One 443 rule per allowed CIDR is expected."
  }

  assert {
    condition     = output.waf_enabled == true
    error_message = "WAF should be associated when enabled."
  }

  assert {
    condition     = output.execute_command_enabled == true
    error_message = "ECS Exec should be on when enabled."
  }
}

run "spot_weights_and_custom_cidr" {
  command = plan

  variables {
    vpc_cidr            = "172.20.0.0/16"
    fargate_weight      = 1
    fargate_spot_weight = 3
    create_alarm_topic  = false
  }

  assert {
    condition     = output.private_subnet_cidrs == ["172.20.10.0/24", "172.20.11.0/24"]
    error_message = "Subnet math should follow the VPC CIDR."
  }

  assert {
    condition = output.capacity_provider_strategy == [
      { capacity_provider = "FARGATE", weight = 1, base = 1 },
      { capacity_provider = "FARGATE_SPOT", weight = 3, base = 0 },
    ]
    error_message = "Capacity provider weights should pass through with an on-demand base of 1."
  }

  assert {
    condition     = output.alarm_topic_arn == null
    error_message = "No SNS topic should be created when create_alarm_topic is false."
  }
}

run "rejects_invalid_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/33"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}

# The following runs target the ecs-service module directly so its own validations are exercised.

run "module_rejects_invalid_fargate_size" {
  command = plan

  module {
    source = "../../modules/ecs-service"
  }

  variables {
    name                    = "sizing-test"
    private_subnet_ids      = ["subnet-aaaa1111", "subnet-bbbb2222"]
    security_group_ids      = ["sg-0123456789abcdef0"]
    target_group_arn        = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:targetgroup/test/0123456789abcdef"
    alb_arn_suffix          = "app/test/0123456789abcdef"
    target_group_arn_suffix = "targetgroup/test/0123456789abcdef"
    container_image         = "public.ecr.aws/docker/library/nginx:stable-alpine"
    cpu                     = 256
    memory                  = 4096
  }

  expect_failures = [var.memory]
}

run "module_rejects_spot_on_arm64" {
  command = plan

  module {
    source = "../../modules/ecs-service"
  }

  variables {
    name                    = "arm-test"
    private_subnet_ids      = ["subnet-aaaa1111", "subnet-bbbb2222"]
    security_group_ids      = ["sg-0123456789abcdef0"]
    target_group_arn        = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:targetgroup/test/0123456789abcdef"
    alb_arn_suffix          = "app/test/0123456789abcdef"
    target_group_arn_suffix = "targetgroup/test/0123456789abcdef"
    container_image         = "public.ecr.aws/docker/library/nginx:stable-alpine"
    cpu_architecture        = "ARM64"
    fargate_spot_weight     = 1
  }

  expect_failures = [var.fargate_spot_weight]
}

run "module_rejects_root_user_and_plaintext_secret" {
  command = plan

  module {
    source = "../../modules/ecs-service"
  }

  variables {
    name                    = "user-test"
    private_subnet_ids      = ["subnet-aaaa1111", "subnet-bbbb2222"]
    security_group_ids      = ["sg-0123456789abcdef0"]
    target_group_arn        = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:targetgroup/test/0123456789abcdef"
    alb_arn_suffix          = "app/test/0123456789abcdef"
    target_group_arn_suffix = "targetgroup/test/0123456789abcdef"
    container_image         = "public.ecr.aws/docker/library/nginx:stable-alpine"
    container_user          = "root"
    secrets                 = [{ name = "API_KEY", value_from = "super-secret-value" }]
  }

  expect_failures = [var.container_user, var.secrets]
}

run "module_valid_large_fargate_size" {
  command = plan

  module {
    source = "../../modules/ecs-service"
  }

  variables {
    name                    = "large-test"
    private_subnet_ids      = ["subnet-aaaa1111", "subnet-bbbb2222"]
    security_group_ids      = ["sg-0123456789abcdef0"]
    target_group_arn        = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:targetgroup/test/0123456789abcdef"
    alb_arn_suffix          = "app/test/0123456789abcdef"
    target_group_arn_suffix = "targetgroup/test/0123456789abcdef"
    container_image         = "public.ecr.aws/docker/library/nginx:stable-alpine"
    cpu                     = 4096
    memory                  = 30720
    enable_autoscaling      = false
    enable_alarms           = false
  }

  assert {
    condition     = output.task_size == { cpu = 4096, memory = 30720 }
    error_message = "4 vCPU / 30 GiB is a valid Fargate size and should plan."
  }

  assert {
    condition     = length(output.autoscaling_policy_names) == 0 && length(output.alarm_names) == 0
    error_message = "Toggles should remove scaling policies and alarms."
  }

  assert {
    condition     = output.container_definition.user == "1000:1000"
    error_message = "Module default should run as a non-root user."
  }
}
