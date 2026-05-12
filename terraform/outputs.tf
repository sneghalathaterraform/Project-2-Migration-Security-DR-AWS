output "instance_id" {
  value = aws_instance.openssl_server.id
}

output "public_ip" {
  value = aws_instance.openssl_server.public_ip
}

output "ssh_command" {
  value = "ssh -i newaccount_key.pem ec2-user@${aws_instance.openssl_server.public_ip}"
}
