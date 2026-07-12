# Environment Setup

## Overview

This project was developed and tested on a Linux workstation using Terraform to provision AWS infrastructure and Ansible to configure the provisioned servers. The environment below documents the exact tool versions used so another engineer can reproduce the same Infrastructure as Code (IaC) pipeline.

| Component        | Version / Configuration                             |
| ---------------- | --------------------------------------------------- |
| Operating System | Ubuntu 26.04 (Linux kernel 7.0.0-27-generic, amd64) |
| Terraform        | v1.15.7                                             |
| Ansible          | ansible-core 2.20.1                                 |
| AWS CLI          | aws-cli 2.31.35                                     |
| Git              | 2.53.0                                              |
| Python           | 3.14.4                                              |
| Jinja2           | 3.1.6                                               |
| PyYAML           | 6.0.3                                               |
| SSH Client       | OpenSSH (system client)                             |

## Cloud Platform

* Cloud Provider: Amazon Web Services (AWS)
* Region: eu-north-1 (Stockholm)
* Compute Service: Amazon EC2
* Operating System Image: Ubuntu Server 22.04 LTS (Canonical AMI, selected dynamically using a Terraform data source)

## Terraform Backend

Terraform uses a remote S3 backend for storing state.

* Backend Type: Amazon S3
* Bucket: `kijanikiosk-terraform-state-louisza`
* State File: `staging/terraform.tfstate`
* Backend Region: `eu-west-1`
* State Encryption: Enabled
* State Locking: Enabled using `use_lockfile = true`

## Repository Structure

The Week 4 Friday project is organised into two primary components:

* `terraform/` – provisions the staging infrastructure using reusable Terraform modules.
* `ansible/` – configures all provisioned servers to the required application state.

A `pipeline.sh` script connects both stages by provisioning infrastructure, generating the Ansible inventory dynamically from Terraform outputs, and executing the Ansible playbook.

## Verification

The environment was verified using:

* `terraform validate`
* `terraform plan`
* `terraform apply`
* `ansible-playbook`
* End-to-end execution through `pipeline.sh`

A second execution confirms reproducibility by producing:

* Terraform: **No changes**
* Ansible: **changed=0** on all managed hosts.
