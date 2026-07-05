# Reflection

## Question 1: The Idempotency Gap

In Week 3, idempotency was achieved by explicitly checking the current state before performing an action. For example, the provisioning script only created the `kk-api` user if it did not already exist. Each operation required its own guard condition.

Terraform achieves idempotency differently. Instead of relying on guard statements in the configuration, it maintains a **state file** (`terraform.tfstate`) that records the infrastructure it has created. The state file stores information such as resource identifiers, current attribute values, dependencies, and metadata that maps Terraform resources to the actual infrastructure. When `terraform plan` is executed, Terraform compares three things: the desired configuration, the recorded state, and the current infrastructure reported by the provider. From this comparison it determines whether a resource should be created, updated, destroyed, or left unchanged.

A situation where the state file can indicate that nothing should change while the infrastructure has actually diverged is when someone modifies the infrastructure outside Terraform without updating the state. For example, an administrator might manually change a firewall rule or replace a virtual machine through the cloud console. If Terraform is unable to detect that change during its refresh, or if the state has become stale, the plan may incorrectly report that no action is required. The correct response is not to edit the state file manually unless absolutely necessary, but to investigate the drift, refresh the state if appropriate, and either import the real infrastructure into Terraform or update the configuration so that the desired state once again matches reality.

---

## Question 2: Declarative Specification Quality

Although my desired-state specification captures the major characteristics of the server, it is not yet detailed enough for another engineer to reproduce the same infrastructure without asking questions.

One area that is under-specified is the operating system image. I identified Ubuntu 22.04 LTS, but I did not include the exact image identifier. Different cloud providers offer multiple Ubuntu 22.04 images with different release dates, kernels, or publishers. If Terraform selected a default image automatically, two engineers could provision different systems while both believing they had followed the specification correctly.

Another missing detail is the networking configuration. While I specified the VPC and subnet, I did not document important characteristics such as availability zone selection or whether a public IP should be automatically assigned by default. Different providers make different assumptions, which could result in an inaccessible server or one exposed to the public Internet unintentionally.

These gaps demonstrate that automation is only as reliable as the specification behind it. Terraform consistently implements whatever is described, but it cannot compensate for ambiguous or incomplete requirements. A precise specification reduces assumptions and leads to predictable infrastructure across different environments.

---

## Question 3: Tool Boundary

Creating a firewall rule that allows port 80 from anywhere is primarily an infrastructure concern, making Terraform the most appropriate tool. Firewall rules belong to the cloud infrastructure and should exist before applications are deployed. Using Ansible or a Bash script would configure the operating system firewall instead of the cloud firewall, potentially leaving the infrastructure inconsistent or requiring repeated manual configuration.

Installing nginx on a running virtual machine is a configuration management task, making Ansible the preferred tool. Ansible is designed to install packages, manage versions, and ensure services are correctly configured. Terraform can execute remote commands through provisioners, but this approach is discouraged because it reduces repeatability and mixes infrastructure provisioning with software configuration. Bash can perform the installation, but it lacks Ansible's idempotency and structured management capabilities.

Verifying that nginx responds to HTTP requests after installation is best handled by a validation or testing step, typically using Bash scripts, monitoring tools, or a CI/CD pipeline. Terraform should not be responsible for operational testing because its purpose is to declare infrastructure rather than validate application behaviour. Similarly, although Ansible can perform health checks, these are generally post-configuration verification tasks rather than configuration itself. Separating verification from provisioning makes troubleshooting and automation easier to manage.

---

## Question 4: From Script to Spec

Some phases of the Week 3 provisioning script translated naturally into declarative specifications. Infrastructure-related decisions such as the operating system, instance type, networking, storage, tags, and firewall rules describe the desired end state rather than the steps required to achieve it. These are well suited to Infrastructure as Code because they define what the environment should look like.

Other phases were much harder to express declaratively. Creating service accounts, configuring permissions, setting ACLs, hardening systemd services, configuring log rotation, and performing verification involve detailed operating system configuration rather than infrastructure provisioning. These activities describe procedures and operational behaviour instead of cloud resources.

This distinction highlights the different responsibilities of infrastructure provisioning and configuration management. Terraform excels at describing infrastructure resources and their relationships, while tools such as Ansible manage the internal state of those resources after they have been created. The difficulty in expressing operating system configuration as declarative infrastructure reinforces why modern DevOps workflows combine multiple specialised tools rather than expecting a single tool to solve every problem.
