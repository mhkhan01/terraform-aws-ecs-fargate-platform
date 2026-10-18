# alb

Internet-facing Application Load Balancer for an ECS Fargate service.

- Security groups for both the ALB and the tasks: the ALB accepts 80/443 from
  `allowed_cidrs`; the task SG accepts the container port from the ALB SG only.
- IP target group with a configurable health check path.
- **Listener behaviour:** when `certificate_arn` is set, port 80 issues a 301 to HTTPS and
  a 443 listener uses `ELBSecurityPolicy-TLS13-1-2-2021-06`. When it is `null`, port 80
  forwards straight to the target group (demo mode, no TLS).
- Access logs to a private, versioned, SSE-S3 bucket with a bucket policy for the regional
  ELB log-delivery account (`data "aws_elb_service_account"`) and TLS-only access.
- Optional WAFv2 web ACL with `AWSManagedRulesCommonRuleSet` and
  `AWSManagedRulesKnownBadInputsRuleSet`.

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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.alb_to_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.service_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.service_from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_elb_service_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidrs"></a> [allowed\_cidrs](#input\_allowed\_cidrs) | IPv4 CIDRs allowed to reach the ALB on 80/443. Defaults to the whole internet for a public site. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ACM certificate ARN. When set, port 80 redirects to an HTTPS listener; when null, port 80 forwards directly (demo mode, no TLS). | `string` | `null` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Port the container listens on; used for the target group and SG rules. | `number` | `80` | no |
| <a name="input_deregistration_delay"></a> [deregistration\_delay](#input\_deregistration\_delay) | Seconds to drain connections before a target is removed. Lower speeds up deploys. | `number` | `30` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Prevent the ALB being deleted by accident. Disable for throwaway demos so destroy works. | `bool` | `true` | no |
| <a name="input_enable_waf"></a> [enable\_waf](#input\_enable\_waf) | Attach a WAFv2 web ACL with AWS managed rule groups. Adds roughly 5-7 USD/month plus per-request charges. | `bool` | `false` | no |
| <a name="input_health_check_matcher"></a> [health\_check\_matcher](#input\_health\_check\_matcher) | HTTP status codes treated as healthy. | `string` | `"200-399"` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | HTTP path the target group polls for health. | `string` | `"/"` | no |
| <a name="input_idle_timeout"></a> [idle\_timeout](#input\_idle\_timeout) | ALB idle connection timeout in seconds. | `number` | `60` | no |
| <a name="input_log_bucket_force_destroy"></a> [log\_bucket\_force\_destroy](#input\_log\_bucket\_force\_destroy) | Allow destroying the log bucket while it still contains objects. Useful for demos only. | `bool` | `false` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days to keep ALB access logs in S3 before expiry. | `number` | `90` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for the ALB, target group, security groups and log bucket. | `string` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Public subnet IDs for the internet-facing ALB (at least two AZs). | `list(string)` | n/a | yes |
| <a name="input_ssl_policy"></a> [ssl\_policy](#input\_ssl\_policy) | TLS negotiation policy for the HTTPS listener. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags merged onto every resource. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC to create the security groups and target group in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_log_bucket"></a> [access\_log\_bucket](#output\_access\_log\_bucket) | Name of the S3 bucket receiving ALB access logs. |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the load balancer. |
| <a name="output_alb_arn_suffix"></a> [alb\_arn\_suffix](#output\_alb\_arn\_suffix) | ARN suffix of the load balancer, used for CloudWatch metrics and auto scaling. |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | Public DNS name of the load balancer. |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group attached to the ALB. |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Route 53 hosted zone ID of the load balancer, for alias records. |
| <a name="output_http_listener_action"></a> [http\_listener\_action](#output\_http\_listener\_action) | Default action of the port-80 listener: 'redirect' when HTTPS is enabled, otherwise 'forward'. |
| <a name="output_https_enabled"></a> [https\_enabled](#output\_https\_enabled) | Whether an HTTPS listener was created. |
| <a name="output_https_ingress_rule_count"></a> [https\_ingress\_rule\_count](#output\_https\_ingress\_rule\_count) | Number of 443 ingress rules on the ALB security group. |
| <a name="output_service_security_group_id"></a> [service\_security\_group\_id](#output\_service\_security\_group\_id) | Security group for the ECS tasks; only the ALB can reach the container port. |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the IP target group the ECS service registers into. |
| <a name="output_target_group_arn_suffix"></a> [target\_group\_arn\_suffix](#output\_target\_group\_arn\_suffix) | ARN suffix of the target group, used for CloudWatch metrics and auto scaling. |
| <a name="output_waf_enabled"></a> [waf\_enabled](#output\_waf\_enabled) | Whether a WAFv2 web ACL is associated with the ALB. |
<!-- END_TF_DOCS -->
