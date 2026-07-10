# Manual Provisioning Decisions - KijaniKiosk API Server

| Decision | Value I chose | Reason |
|-----------|---------------|--------|
| Cloud provider | Multipass | Local virtualization for the lab without requiring a cloud account. |
| Region | Local machine | Multipass runs locally rather than in a cloud region. |
| Operating system | Ubuntu 22.04 LTS | Required by the lab instructions. |
| Instance type | 1 vCPU, 1 GB RAM, 5 GB disk | Matches the lab specification. |
| VPC | N/A | Multipass provides virtual networking instead of cloud VPCs. |
| Subnet | Default Multipass network | Automatically assigned by Multipass. |
| Security group | N/A | Networking is managed locally rather than through cloud security groups. |
| SSH key pair | Multipass managed | Multipass manages SSH access automatically. |
| Root volume size | 5 GB | Default size requested by the lab. |
| Public IP? | No | VM is accessible only from the host. |
| Tags / labels | kijanikiosk-api | Used to identify the VM. |
