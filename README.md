# Terraform AWS Infrastructure

This repository contains Terraform configuration for AWS infrastructure
in `ap-south-1` (Mumbai), remote state in S3, native S3 state locking,
and email notifications for matching S3 state-object events through SNS.

> **Accuracy note:** This README is based on the project details
> discussed so far. Verify resource names, variable names,
> security-group rules, and outputs against the current `.tf` files
> before treating this as a complete inventory. Never commit Terraform
> state, credentials, private keys, or sensitive variable values.

## Project goals

-   Manage AWS resources as code using Terraform.
-   Store Terraform state remotely in Amazon S3.
-   Use Terraform's native S3 lock-file mechanism.
-   Notify an email address when matching Terraform state objects are
    created in S3.
-   Keep source code in GitHub while excluding state and sensitive
    files.
-   Prepare separate Dev, Stage, and Prod environments with separate
    state keys.

## Architecture

``` text
Terraform CLI
   |-- AWS provider --> AWS infrastructure
   |
   |-- S3 backend --> s3://adarsh-tfstate-dynamobucket/terraform-project/terraform.tfstate
   |                      |
   |                      +-- S3 ObjectCreated event
   |                                |
   |                                v
   |                           SNS topic
   |                                |
   |                                v
   |                        Confirmed email subscription
```

## Repository layout

The working directory used during setup was
`/home/ec2-user/terraform-project`.

``` text
terraform-project/
├── backend.tf
├── config.tf
├── main.tf
├── notifications.tf
├── output.tf
├── remote-state/
├── resource.tf
├── variable.tf
├── terraform.tfvars
├── terraform.tfstate          # generated; do not commit
└── terraform.tfstate.backup   # generated; do not commit
```

  -----------------------------------------------------------------------
  File                                Intended responsibility
  ----------------------------------- -----------------------------------
  `backend.tf`                        S3 backend configuration

  `main.tf`, `resource.tf`            AWS resources (confirm exact
                                      contents)

  `config.tf`                         Provider/data/shared configuration
                                      (confirm exact contents)

  `variable.tf`                       Input variable declarations and
                                      types

  `terraform.tfvars`                  Variable values; keep private if
                                      account-specific or sensitive

  `output.tf`                         Terraform outputs

  `notifications.tf`                  SNS topic, topic policy, email
                                      subscription, and S3 notification

  `remote-state/`                     Separate bootstrap configuration,
                                      if still used
  -----------------------------------------------------------------------

## Prerequisites and region

-   AWS region: `ap-south-1`
-   Terraform and AWS CLI installed
-   AWS credentials configured through an approved method
-   IAM permissions sufficient for the resources in this project
-   An email address that can confirm an SNS subscription

Check tools and the active identity:

``` bash
terraform version
aws --version
aws sts get-caller-identity
```

Never paste credentials or private keys into the README, GitHub, or
support messages.

## S3 remote state

The intended `backend.tf` configuration for the main project is:

``` hcl
terraform {
  backend "s3" {
    bucket       = "adarsh-tfstate-dynamobucket"
    key          = "terraform-project/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

-   `bucket`: S3 bucket holding the state object.
-   `key`: object path for this Terraform configuration. Each
    independent project/environment needs its own key.
-   `region`: region containing the bucket.
-   `encrypt = true`: requests server-side encryption for the state
    object.
-   `use_lockfile = true`: enables Terraform's native S3 lock-file
    mechanism to coordinate state-writing operations.

Terraform state may contain sensitive values. Restrict bucket access and
do not commit state files to Git.

Initialize Terraform from the directory containing this configuration:

``` bash
terraform init
```

If Terraform asks whether to migrate existing local state to S3, confirm
only when that migration is intended. `terraform init -reconfigure`
tells Terraform to accept the configured backend without migrating
state; it is not a substitute for a needed migration. Securely back up
state before changing backend settings.

## Locking and DynamoDB

The main backend block uses `use_lockfile = true`, which is Terraform's
native S3 locking option. A DynamoDB table named `terraform-lock` was
also created during the earlier setup, but the backend block above does
**not** reference it. Therefore, this backend is not using that DynamoDB
table for locking. Verify whether the table belongs to the separate
bootstrap configuration before changing or deleting it.

## SNS email alerts for S3 state changes

The intended notification flow is:

1.  Terraform creates an SNS topic.
2.  An SNS topic policy allows the S3 bucket to publish to the topic.
3.  Terraform creates an email subscription.
4.  The recipient confirms the subscription using the email from AWS.
5.  S3 publishes matching object-created events to SNS, which sends
    email alerts.

The notification settings discussed for `notifications.tf` are:

``` hcl
events        = ["s3:ObjectCreated:*"]
filter_prefix = "terraform-project/"
filter_suffix = ".tfstate"
```

These are settings only, not a complete standalone resource. Keep the
actual topic ARN reference and complete resource syntax from the
project's `notifications.tf`.

-   `s3:ObjectCreated:*` matches object-creation/write events.
-   `filter_prefix` restricts events to the specified folder-like key
    prefix.
-   `filter_suffix` restricts events to keys ending in `.tfstate`.
-   The S3 lock file normally ends in `.tflock`, so it does not match
    the `.tfstate` suffix.
-   SNS email delivery will not begin until the recipient confirms the
    subscription.
-   `terraform plan` alone normally does not write state, so it should
    not be expected to trigger this alert. State-writing operations may
    generate an event, delivered asynchronously.

**Important:** `aws_s3_bucket_notification` manages the bucket's
notification configuration as a whole. If the bucket already has other
notifications, combine them in one Terraform-managed configuration to
avoid overwriting them.

Validate before applying:

``` bash
terraform fmt -check
terraform validate
terraform plan
```

Check **Amazon SNS → Topics → topic → Subscriptions** to verify the
email subscription is confirmed. Verify the S3 event notification
configuration and filters in the S3 console as well.

## Variables, maps, and security groups

Variables make a configuration reusable. Declare types/descriptions in
`variable.tf` and supply environment-specific values through environment
configuration. Do not commit sensitive `terraform.tfvars` files.

A `map(string)` stores string values indexed by string keys. For
example:

``` hcl
variable "security_group_names" {
  description = "Security group names by purpose"
  type        = map(string)
  default = {
    web = "web-sg"
    ssh = "admin-ssh-sg"
  }
}
```

A map entry can be referenced as `var.security_group_names["web"]` and
maps can be iterated with `for_each`. This is an illustrative example;
verify the real map variable and keys in the repository before
documenting them as actual resources.

Security groups are stateful virtual firewalls. Review the actual
ingress and egress rules in the Terraform code. For web workloads, allow
HTTP only from the intended source, and restrict SSH to trusted
administrative sources or use AWS Systems Manager Session Manager where
suitable. Avoid SSH from `0.0.0.0/0` in production. A security-group
name alone does not reveal its effective permissions.

## Other infrastructure concepts discussed

Earlier hands-on work covered EC2, VPCs, public/private subnets,
Internet Gateway, NAT Gateway, route tables, a bastion host, an
Application Load Balancer, target groups, and an Auto Scaling Group.
These should be listed as deployed resources only if they are present in
the current configuration and Terraform state.

Typical traffic flow: - Public subnet routes may send internet traffic
through an Internet Gateway. - Private subnet instances may use a NAT
Gateway for outbound internet access. - An ALB forwards requests to
registered targets and checks target health. - An Auto Scaling Group
maintains the configured desired instance count.

Verify route tables, security-group relationships, listener and
target-group ports, health-check paths, and ASG subnet settings before
troubleshooting.

## Common commands

Run these from the correct Terraform project directory:

``` bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply
terraform state list
terraform state show <resource_address>
terraform output
terraform workspace show
```

Review the plan before approving `terraform apply`.
`terraform state show` can reveal sensitive values; sanitize output
before sharing.

## Verify the S3 state

``` bash
aws s3 ls s3://adarsh-tfstate-dynamobucket/ --recursive
```

During setup, separate state objects were observed for the bootstrap and
main project:

``` text
dev/terraform.tfstate
terraform-project/terraform.tfstate
```

These are different keys and should remain separate if they belong to
separate Terraform configurations. Do not manually edit or delete state
objects. Always run `terraform state list` from the intended project
directory because it reflects the active configuration/backend.

## Troubleshooting / RCA notes

### Undeclared AMI data source

**Cause:** A resource refers to `data.aws_ami.amazon_linux.id`, but the
matching data source is missing or named differently.\
**Fix:** Ensure the `data "aws_ami" "amazon_linux"` block exists and the
reference uses the exact local name. Run `terraform validate` and
`terraform plan`.

### EC2 or AMI selection errors

**Possible causes:** The AMI filter matches no image, wrong
region/architecture, or invalid instance parameters.\
**Fix:** Verify provider region, AMI owner/name filters, architecture,
and instance type.

### S3 state missing or not updating

**Possible causes:** Running Terraform from another directory/backend,
wrong state key, backend not initialized, or no state-writing
operation.\
**Fix:** Check `backend.tf`, run `terraform init` from the correct
directory, and list the bucket objects.

### SNS email not received

**Possible causes:** Subscription is pending, event prefix/suffix does
not match the object key, bucket notification was not applied, or no
matching object event occurred.\
**Fix:** Confirm the subscription, verify topic policy and bucket
notification filters, and check the exact S3 key. Delivery is
asynchronous.

### S3 notification configuration conflict

**Cause:** Multiple resources or tools manage the bucket's notification
configuration.\
**Fix:** Consolidate notifications into one `aws_s3_bucket_notification`
resource and inspect the plan.

### ALB targets unhealthy

**Possible causes:** Application is stopped, port/path mismatch, target
security group does not allow traffic from the ALB security group, or
subnet/network configuration is wrong.\
**Fix:** Inspect target health reason, application service,
listener/target ports, health-check path, routes, and security groups.

### NAT route shows `Blackhole`

**Cause:** Route target points to a missing, deleted, or unavailable NAT
Gateway.\
**Fix:** Verify NAT Gateway status and the private route table target
before changing the route.

### SSH `Permission denied (publickey,...)`

**Possible causes:** Wrong key, wrong Linux username, key-pair mismatch,
or security-group source restriction.\
**Fix:** Confirm key pair, username, local key permissions, and network
rules. Never share private-key contents.

### Package installation times out

**Possible causes:** Missing outbound path, NAT/route issue, DNS issue,
or temporary repository outage.\
**Fix:** Check DNS, outbound connectivity, routes, security
groups/NACLs, and repository availability before assuming the package is
missing.

## Dev, Stage, and Prod state separation

Use a unique state key for each environment:

  Environment   Example S3 state key
  ------------- ---------------------------
  Dev           `dev/terraform.tfstate`
  Stage         `stage/terraform.tfstate`
  Prod          `prod/terraform.tfstate`

Each independent environment must have its own state key. Do not allow
Dev, Stage, and Prod to write to the same state object.

Suggested future repository layout:

``` text
terraform-aws-infrastructure/
├── modules/
│   ├── ec2/
│   └── networking/
├── environments/
│   ├── dev/
│   ├── stage/
│   └── prod/
├── .gitignore
└── README.md
```

Refactor into modules only after reviewing the current state and
resource addresses; careless refactoring can cause Terraform to propose
replacements.

## GitHub and security checklist

Recommended `.gitignore` entries:

``` gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
*.pem
*.key
crash.log
```

Remember: `.gitignore` does not untrack files that were already
committed. Before pushing, run:

``` bash
git status
git diff --cached --stat
git diff --cached
```

Do not commit state files, backups, real variable files containing
sensitive values, credentials, or private keys. If a secret was pushed,
revoke/rotate it immediately; deleting it in a later commit does not
remove it from Git history. Use least-privilege IAM, restrict the state
bucket, and consider S3 versioning and recovery controls.

## Cleanup

Review destruction carefully:

``` bash
terraform plan -destroy
terraform destroy
```

Only destroy the intended practice environment. Do not delete the
remote-state bucket, state objects, lock files, or DynamoDB table until
you confirm which configuration owns them and whether any environment
depends on them.

## Final verification checklist

-   [ ] Correct backend bucket, region, and key verified
-   [ ] Terraform initialized against the intended backend
-   [ ] State object visible in S3
-   [ ] Native S3 locking enabled
-   [ ] SNS email subscription confirmed
-   [ ] S3 notification filters match the intended state key
-   [ ] Actual security-group ingress/egress rules reviewed
-   [ ] Dev, Stage, and Prod use separate state keys
-   [ ] `.gitignore` excludes state and sensitive files
-   [ ] GitHub repository checked for already-committed sensitive files
-   [ ] README reconciled with the exact current `.tf` files and outputs
