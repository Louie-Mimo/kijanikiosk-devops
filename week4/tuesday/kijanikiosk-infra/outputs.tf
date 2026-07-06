output "instance_public_ips" {
  description = "Public IPs of all application servers"

  value = {
    for name, server in module.app_servers :
    name => server.public_ip
  }
}

output "instance_ids" {
  description = "Instance IDs of all application servers"

  value = {
    for name, server in module.app_servers :
    name => server.instance_id
  }
}

output "ssh_commands" {
  value = {
    for name, server in module.app_servers :
    name => "ssh -i ~/.ssh/kijanikiosk-key.pem ubuntu@${server.public_ip}"
  }
}
