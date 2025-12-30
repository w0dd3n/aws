resource "aws_vpc" "kuma_vpc" {
  cidr_block           = var.vpc_ip_range
  enable_dns_hostnames = true

  tags = {
    Name = "kuma_vpc"
  }
}

resource "aws_internet_gateway" "kuma_igw" {
  vpc_id = aws_vpc.kuma_vpc.id

  tags = {
    Name = "kuma_igw"
  }
}

resource "aws_subnet" "kuma_subnet_pub" {
  vpc_id                  = aws_vpc.kuma_vpc.id
  cidr_block              = var.subnet_internal_ip_range
  availability_zone       = "${var.region_name}a"
  map_public_ip_on_launch = true

  depends_on = [aws_internet_gateway.kuma_igw]

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_route_table" "kuma_rt_public" {
  vpc_id = aws_vpc.kuma_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kuma_igw.id
  }

  tags = {
    Name = "kuma_rt_public"
  }
}

resource "aws_route_table_association" "kuma_rta_public" {
  subnet_id      = aws_subnet.kuma_subnet_pub.id
  route_table_id = aws_route_table.kuma_rt_public.id
}

resource "aws_security_group" "kuma_nsg_ec2_public_access" {
  name        = "kuma_nsg_ec2_public_access"
  description = "Allow inbound/outbound traffic for EC2 Kuma instance"
  vpc_id      = aws_vpc.kuma_vpc.id

  tags = {
    Name = "kuma_nsg_ec2_public_access"
  }
}

resource "aws_vpc_security_group_ingress_rule" "kuma_racl_ingress_allow_ssh" {
  for_each = toset(var.allowed_mgmt_eip)

  security_group_id = aws_security_group.kuma_nsg_ec2_public_access.id

  cidr_ipv4   = each.value
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  tags = {
    Name = "allow_ssh_from_${each.value}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "kuma_racl_ingress_allow_https" {
  for_each = toset(var.allowed_clients_eip)

  security_group_id = aws_security_group.kuma_nsg_ec2_public_access.id
  
  cidr_ipv4   = each.value
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  tags = {
    Name = "allow_https_from_${each.value}"
  }
}

resource "aws_vpc_security_group_egress_rule" "kuma_racl_egress_allow_all" {
  security_group_id = aws_security_group.kuma_nsg_ec2_public_access.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name = "allow_all_outbound"
  }
}

resource "aws_key_pair" "kuma_admin_kp" {
  key_name   = "kuma_admin_kp"
  public_key = file(var.pubkey_path)

  tags = {
    Name = "kuma_admin_kp"
  }
}

resource "aws_instance" "kuma_ec2_default" {
  ami           = "ami-0808dd1ba12547041" # Debian 13 (HVM)
  instance_type = "t2.medium"              # 2 vCPU IA64 with 4 GB RAM
  key_name      = aws_key_pair.kuma_admin_kp.key_name

  root_block_device {
    volume_size           = 10
    volume_type           = "standard"
    delete_on_termination = true
  }

  subnet_id              = aws_subnet.kuma_subnet_pub.id
  private_ip             = var.ec2_ip_private
  vpc_security_group_ids = [aws_security_group.kuma_nsg_ec2_public_access.id]

  depends_on = [aws_key_pair.kuma_admin_kp]

  tags = {
    Name = "kuma_ec2_default"
  }
}

resource "aws_eip" "kuma_eip_default" {
  domain = "vpc"

  instance                  = aws_instance.kuma_ec2_default.id
  associate_with_private_ip = var.ec2_ip_private

  depends_on = [aws_instance.kuma_ec2_default, aws_internet_gateway.kuma_igw]

  tags = {
    Name = "kuma_eip_default"
  }
}