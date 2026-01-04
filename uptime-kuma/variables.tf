 variable "aws_ak_id" {
  description = "Project Access Key value to be declared per envs"
  type        = string
  default     = ""
  sensitive   = true
  nullable    = false
 }

variable "aws_sk_id" {
  description = "Project Secret Key value to be declared per envs"
  type        = string
  default     = ""
  sensitive   = true
  nullable    = false
 }

 variable "region_name" {
  description = "Europe/Paris"
  default     = "eu-west-3"
  type        = string
  sensitive   = false
  nullable    = false
   
 }

variable "vpc_ip_range" {
  description = "VPC Network IP Range"
  type        = string
  sensitive   = false
  nullable    = false
}

variable "subnet_internal_ip_range" {
  description = "Internal Subnet IP Range"
  type        = string
  sensitive   = false
  nullable    = false
}

variable "pubkey_path" {
  description = "Local filepath to SSH Public key for Management of instance"
  type        = string
  sensitive   = false
  nullable    = false
}

variable "ec2_ip_private" {
  description = "Internal Private IP of EC2 Instance"
  type        = string
  sensitive   = false
  nullable    = false
}

variable "allowed_mgmt_eip" {
  description   = "Restricted list of remote IP Addresses for management purpose"
  type          = list(string)
  sensitive     = false
  nullable      = false
}

variable "allowed_clients_eip" {
  description   = "Restricted list of remote IP Addresses to access Uptime Kuma Service"
  type          = list(string)
  sensitive     = false
  nullable      = false
}

variable "ssl_cert_path" {
  description = "Path to SSL/TLS certificate with private key (PEM format)"
  type        = string
  sensitive   = false
  nullable    = false
}