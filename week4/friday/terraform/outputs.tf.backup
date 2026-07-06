output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.kk_api.public_ip
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.kk_api.id
}

output "ssh_command" {
  description = "SSH command"
  value = "ssh -i ~/.ssh/kijanikiosk-key.pem ubuntu@${aws_instance.kk_api.public_ip}"
}
