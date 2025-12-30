output "public_ip" {
  description = "Public IP Address to reach EC2 Instance"
  value       = aws_eip.kuma_eip_default.public_ip
}