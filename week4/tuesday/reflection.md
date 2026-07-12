# Question 1: The State File as a System

Terraform knows about attributes such as the instance ID, private IP address, public IP address, availability zone, and network interface because it communicates with the cloud provider through the AWS provider plugin. During `terraform apply`, AWS creates the resources and returns their actual attributes to Terraform. Terraform then records those values in the `terraform.tfstate` file so it can track the infrastructure and compare it with the desired configuration during future plans.

When `terraform destroy` is run successfully, Terraform deletes the managed resources from AWS and updates the state file by removing those resources. The state is left empty because Terraform is no longer managing any infrastructure.

If the state file were deleted manually without first destroying the infrastructure, Terraform would lose its record of the existing resources even though they would still exist in AWS. On the next `terraform plan`, Terraform would assume the resources do not exist and would plan to create new ones, which could lead to duplicate infrastructure or resource conflicts.

The correct recovery procedure is to restore the state file from a backup if one exists, or use `terraform import` to import the existing AWS resources back into Terraform's state before continuing to manage them.

# Question 2: The (known after apply) Values

Some attributes are shown as **(known after apply)** because AWS does not assign them until the resource has actually been created. Terraform can predict what it will request from AWS, but it cannot know values that AWS generates automatically.

One example from my plan was the **public IP address**. AWS assigns the public IP when the EC2 instance launches, so Terraform cannot know it beforehand.

Another example was the **availability zone**. Although the instance was deployed in the `eu-north-1` region, AWS selected the specific availability zone (`eu-north-1b`) only during resource creation.

If an output depends on a value that is **(known after apply)**, Terraform also displays that output as **(known after apply)** during `terraform plan`. The actual value only becomes available after a successful `terraform apply`.

# Question 3: Hardcoded vs Variable

Hardcoding my own public IP address in the security group's SSH rule works for my personal environment, but it is not suitable for a shared team configuration. Every team member has a different public IP address, and my IP could also change over time. This would require editing the Terraform source code whenever someone else wanted to use the configuration, making collaboration difficult.

A better solution is to define a Terraform variable for the allowed SSH IP addresses and reference that variable in the security group. Each environment or team member can then provide different values through `terraform.tfvars` without modifying the Terraform code itself.

Since a security group may need to allow multiple IP addresses, the appropriate variable type would be `list(string)`. This allows Terraform to accept one or more CIDR blocks, making the configuration reusable across different users and environments.

# Question 4: What Tuesday's Configuration Cannot Do

For a production deployment, several values would likely be different from staging. These include the deployment environment name, AWS region, instance type, VPC, subnet, security group rules, SSH key pair, number of EC2 instances, and resource tags.

With today's configuration, handling these differences would become difficult because many changes would require editing the Terraform source code directly. For example, deploying production might require a larger instance type, a different VPC, and multiple EC2 instances. Manually changing the configuration for each deployment increases the risk of mistakes and makes it harder to maintain consistent infrastructure across environments.

A better approach is to keep a single Terraform configuration while supplying different variable values for each environment. This allows the same code to deploy staging and production simply by changing the input variables rather than modifying the source code. This is the problem Wednesday's lesson is designed to solve.
