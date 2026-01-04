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

resource "aws_vpc_security_group_ingress_rule" "kuma_racl_ingress_allow_http" {
  for_each = toset(var.allowed_clients_eip)

  security_group_id = aws_security_group.kuma_nsg_ec2_public_access.id
  
  cidr_ipv4   = each.value
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  tags = {
    Name = "allow_http_from_${each.value}"
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

# Configuration cloud-init pour installer Docker, Uptime Kuma et NGINX
data "cloudinit_config" "kuma_init" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      package_update  = true
      package_upgrade = true

      packages = [
        "ca-certificates",
        "curl",
        "gnupg",
        "nginx"
      ]

      write_files = [
        {
          path        = "/opt/uptime-kuma/docker-compose.yml"
          permissions = "0644"
          owner       = "root:root"
          content = <<-EOT
            version: '3.8'
            
            services:
              uptime-kuma:
                image: louislam/uptime-kuma:latest
                container_name: uptime-kuma
                restart: always
                ports:
                  - "127.0.0.1:3001:3001"
                volumes:
                  - /opt/uptimekuma/data:/app/data
                environment:
                  - TZ=Europe/Paris
                  - UMASK=0022
                networks:
                  - kuma_network
                healthcheck:
                  test: ["CMD", "curl", "-f", "http://localhost:3001"]
                  interval: 30s
                  retries: 3
                  start_period: 10s
                  timeout: 5s
                logging:
                  driver: "json-file"
                  options:
                    max-size: "10m"
                    max-file: "3"
            
            networks:
              kuma_network:
                driver: bridge
          EOT
        },
        {
          path        = "/etc/nginx/sites-available/uptime-kuma"
          permissions = "0644"
          owner       = "root:root"
          content = <<-EOT
            # Redirection HTTP vers HTTPS
            server {
                listen 80;
                listen [::]:80;
                server_name _;
                return 301 https://$host$request_uri;
            }
            
            # Configuration HTTPS avec reverse proxy pour Uptime Kuma
            server {
                listen 443 ssl http2;
                listen [::]:443 ssl http2;
                server_name _;
                
                # Certificats SSL
                ssl_certificate /opt/ssl/certificate.pem;
                ssl_certificate_key /opt/ssl/certificate.pem;
                
                # Configuration SSL optimisée
                ssl_protocols TLSv1.2 TLSv1.3;
                ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
                ssl_prefer_server_ciphers off;
                ssl_session_cache shared:SSL:10m;
                ssl_session_timeout 10m;
                
                # Headers de sécurité
                add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
                add_header X-Frame-Options "SAMEORIGIN" always;
                add_header X-Content-Type-Options "nosniff" always;
                add_header X-XSS-Protection "1; mode=block" always;
                
                # Configuration du reverse proxy pour Uptime Kuma
                location / {
                    proxy_pass http://127.0.0.1:3001;
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                    
                    # Configuration WebSocket (CRITIQUE pour Uptime Kuma)
                    proxy_http_version 1.1;
                    proxy_set_header Upgrade $http_upgrade;
                    proxy_set_header Connection "upgrade";
                    
                    # Timeouts
                    proxy_connect_timeout 60s;
                    proxy_send_timeout 60s;
                    proxy_read_timeout 60s;
                }
            }
          EOT
        },
        {
          path        = "/opt/ssl/certificate.pem"
          permissions = "0600"
          owner       = "root:root"
          encoding    = "b64"
          content     = filebase64(var.ssl_cert_path)
        }
      ]

      runcmd = [
        # Installation de Docker
        "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh",
        "sh /tmp/get-docker.sh",
        "usermod -aG docker admin",
        
        # Installation de Docker Compose v2
        "apt-get install -y docker-compose-plugin",
        
        # Démarrage du service Docker
        "systemctl enable docker",
        "systemctl start docker",
        
        # Création du répertoire data
        "mkdir -p /opt/uptimekuma/data",
        "chown -R root:root /opt/uptimekuma",
        
        # Configuration de NGINX
        "rm -f /etc/nginx/sites-enabled/default",
        "ln -sf /etc/nginx/sites-available/uptime-kuma /etc/nginx/sites-enabled/",
        "nginx -t",
        "systemctl enable nginx",
        "systemctl restart nginx",
        
        # Démarrage d'Uptime Kuma
        "cd /opt/uptime-kuma && docker compose up -d",
        
        # Attendre que le conteneur démarre
        "sleep 10",
        
        # Vérification du statut
        "docker ps | grep uptime-kuma",
        
        # Nettoyage
        "rm /tmp/get-docker.sh"
      ]
    })
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

  user_data = data.cloudinit_config.kuma_init.rendered

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

