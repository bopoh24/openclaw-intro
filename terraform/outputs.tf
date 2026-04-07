output "server_ip" {
  description = "Public IPv4 address of the server"
  value       = hcloud_server.openclaw.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 address of the server"
  value       = hcloud_server.openclaw.ipv6_address
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh root@${hcloud_server.openclaw.ipv4_address}"
}

