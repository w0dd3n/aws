output "public_ip" {
  description = "Public IP Address to reach Uptime Kuma"
  value       = aws_eip.kuma_eip_default.public_ip
}