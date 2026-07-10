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

output "api_server_ip" {
  value = module.app_servers["api"].public_ip
}

output "payments_server_ip" {
  value = module.app_servers["payments"].public_ip
}

output "logs_server_ip" {
  value = module.app_servers["logs"].public_ip
}
