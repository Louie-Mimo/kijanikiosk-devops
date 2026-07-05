# KijaniKiosk API Server - Desired State Specification

## Identity

- Name: kijanikiosk-api-staging
- Environment tag: staging
- Owner tag: amina

## Compute

- Provider: Multipass
- Region: Local machine
- Instance type: 1 vCPU, 1 GB RAM
- Operating system: Ubuntu 22.04 LTS

## Networking

- VPC: Default Multipass virtual network
- Subnet: Default
- Assign public IP: No

## Access Control

- SSH access: Multipass managed
- HTTP access: Not configured
- All other inbound: Deny
- All outbound: Allow

## Storage

- Root volume: 5 GB

## Authentication

- SSH key pair name: Managed by Multipass

## What must NOT exist on this server after provisioning

- No password authentication
- No unnecessary services
- No world-writable directories outside `/tmp`

## Open questions

- How should firewall rules be expressed when converting this configuration into Terraform?
- Should networking remain on the default virtual network or be explicitly configured?

## Hardest Decision and Why

The most difficult decision was determining the networking configuration. Multipass abstracts much of the underlying network setup, so there is less visibility than when provisioning a cloud VM. While the default network works well for local development, Terraform requires infrastructure to be described explicitly. Understanding which networking components should become variables and which should remain defaults will be important when translating this specification into Terraform.
