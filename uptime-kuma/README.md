# Uptime Kuma - AWS Terraform Deployment

Déploiement automatisé d'une instance [Uptime Kuma](https://github.com/louislam/uptime-kuma) sur AWS EC2 avec Terraform.

## 📋 Table des matières

- [À propos](#à-propos)
- [Prérequis](#prérequis)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Mise à jour](#mise-à-jour)
- [Sécurité](#sécurité)
- [Dépannage](#dépannage)
- [Contribuer](#contribuer)
- [Licence](#licence)

## 🎯 À propos

Ce projet permet de déployer automatiquement Uptime Kuma, un outil de monitoring élégant et auto-hébergé, sur AWS EC2 en utilisant Terraform. L'infrastructure créée comprend :

- Un VPC dédié avec subnet public
- Une instance EC2 (Debian 13) avec Uptime Kuma
- Un Security Group configuré pour SSH et HTTPS
- Une Elastic IP pour un accès stable
- Une Internet Gateway pour la connectivité externe

### Qu'est-ce qu'Uptime Kuma ?

Uptime Kuma est un outil de monitoring open-source qui permet de surveiller :
- HTTP(s) / TCP / Ping / DNS
- Docker Containers
- Steam Game Servers
- Et bien plus...

Il offre également :
- Une interface utilisateur moderne et réactive
- Plus de 90 systèmes de notifications (Telegram, Discord, Slack, Email, etc.)
- Des pages de statut personnalisables
- Un système d'alertes configurable

## 🔧 Prérequis

### Logiciels requis

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configuré avec vos credentials
- Une paire de clés SSH (publique/privée)

### Compte AWS

- Un compte AWS actif
- Des credentials IAM avec les permissions suivantes :
  - EC2 (instances, security groups, key pairs)
  - VPC (création et gestion)
  - EIP (allocation et association)

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│           AWS VPC (kuma_vpc)            │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  Public Subnet                    │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │   EC2 Instance              │ │ │
│  │  │   - Debian 13               │ │ │
│  │  │   - t2.medium               │ │ │
│  │  │   - Uptime Kuma             │ │ │
│  │  │   - Private IP fixe         │ │ │
│  │  └─────────────────────────────┘ │ │
│  │            ▲                      │ │
│  │            │                      │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │   Security Group            │ │ │
│  │  │   - SSH (22)                │ │ │
│  │  │   - HTTPS (443)             │ │ │
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
│                 ▲                       │
│                 │                       │
│  ┌──────────────────────────┐          │
│  │  Internet Gateway        │          │
│  └──────────────────────────┘          │
└─────────────────────────────────────────┘
           ▲
           │
    ┌──────────────┐
    │ Elastic IP   │
    └──────────────┘
```

## 📦 Installation

### 1. Cloner le dépôt

```bash
git clone https://github.com/w0dd3n/aws.git
cd aws/uptime-kuma
```

### 2. Créer une paire de clés SSH (si nécessaire)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/kuma_admin_key -C "admin@uptime-kuma"
```

### 3. Initialiser Terraform

```bash
terraform init
```

### 4. Configurer les variables

Créez un fichier `terraform.tfvars` à la racine du projet :

```hcl
# Région AWS
region_name = "eu-west-3"

# Configuration réseau
vpc_ip_range              = "10.0.0.0/16"
subnet_internal_ip_range  = "10.0.1.0/24"

# Configuration EC2
ec2_ip_private = "10.0.1.50"
pubkey_path    = "~/.ssh/kuma_admin_key.pub"

# Sécurité - IPs autorisées pour SSH (remplacez par vos IPs)
allowed_mgmt_eip = [
  "203.0.113.0/32",  # Votre IP publique
]

# Sécurité - IPs autorisées pour HTTPS (clients)
allowed_clients_eip = [
  "0.0.0.0/0",  # Tout le monde (à restreindre en production)
]
```

### 5. Vérifier le plan d'exécution

```bash
terraform plan
```

### 6. Déployer l'infrastructure

```bash
terraform apply
```

Tapez `yes` pour confirmer le déploiement.

## ⚙️ Configuration

### Variables disponibles

| Variable | Description | Type | Défaut |
|----------|-------------|------|--------|
| `region_name` | Région AWS de déploiement | string | - |
| `vpc_ip_range` | Plage CIDR du VPC | string | - |
| `subnet_internal_ip_range` | Plage CIDR du subnet | string | - |
| `ec2_ip_private` | IP privée de l'instance EC2 | string | - |
| `pubkey_path` | Chemin vers la clé SSH publique | string | - |
| `allowed_mgmt_eip` | Liste des IPs autorisées pour SSH | list(string) | - |
| `allowed_clients_eip` | Liste des IPs autorisées pour HTTPS | list(string) | - |

### Structure du projet

```
uptime-kuma/
├── main.tf           # Ressources principales AWS
├── variables.tf      # Déclarations des variables
├── outputs.tf        # Sorties Terraform
├── terraform.tfvars  # Valeurs des variables (à créer)
└── README.md         # Ce fichier
```

## 🚀 Utilisation

### Connexion SSH à l'instance

Une fois le déploiement terminé, récupérez l'Elastic IP :

```bash
terraform output elastic_ip
```

Connectez-vous à l'instance :

```bash
ssh -i ~/.ssh/kuma_admin_key admin@<ELASTIC_IP>
```

### Installation d'Uptime Kuma sur l'instance

Après connexion SSH, installez Uptime Kuma :

#### Option 1 : Docker (recommandé)

```bash
# Installer Docker
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Déployer Uptime Kuma
mkdir ~/uptime-kuma && cd ~/uptime-kuma
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:2
    container_name: uptime-kuma
    volumes:
      - ./data:/app/data
    ports:
      - "3001:3001"
    restart: unless-stopped
EOF

docker-compose up -d
```

#### Option 2 : Installation depuis les sources

```bash
# Installer Node.js et dépendances
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs git

# Cloner et installer Uptime Kuma
cd ~
git clone https://github.com/louislam/uptime-kuma.git
cd uptime-kuma
npm run setup

# Installer PM2
sudo npm install pm2 -g
pm2 install pm2-logrotate

# Démarrer Uptime Kuma
pm2 start server/server.js --name uptime-kuma
pm2 save
pm2 startup
```

### Configuration d'un reverse proxy (optionnel)

Pour accéder à Uptime Kuma via HTTPS sur le port 443, configurez Nginx :

```bash
sudo apt install -y nginx certbot python3-certbot-nginx

# Configuration Nginx
sudo tee /etc/nginx/sites-available/uptime-kuma <<EOF
server {
    listen 443 ssl http2;
    server_name <VOTRE_DOMAINE>;

    ssl_certificate /etc/letsencrypt/live/<VOTRE_DOMAINE>/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/<VOTRE_DOMAINE>/privkey.pem;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/uptime-kuma /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Obtenir un certificat SSL
sudo certbot --nginx -d <VOTRE_DOMAINE>
```

### Accès à l'interface web

Ouvrez votre navigateur et accédez à :
- Sans reverse proxy : `http://<ELASTIC_IP>:3001`
- Avec reverse proxy : `https://<VOTRE_DOMAINE>`

Lors de la première connexion, créez votre compte administrateur.

## 🔄 Mise à jour

### Mise à jour de l'infrastructure Terraform

```bash
# Vérifier les changements
terraform plan

# Appliquer les mises à jour
terraform apply
```

### Mise à jour d'Uptime Kuma

#### Avec Docker

```bash
cd ~/uptime-kuma
docker-compose pull
docker-compose up -d
```

#### Avec PM2

```bash
cd ~/uptime-kuma
pm2 stop uptime-kuma
git pull
npm install
pm2 restart uptime-kuma
pm2 save
```

## 🔒 Sécurité

### Bonnes pratiques recommandées

1. **Restreindre l'accès SSH** : Limitez `allowed_mgmt_eip` à vos IPs publiques uniquement
2. **Restreindre l'accès HTTPS** : En production, limitez `allowed_clients_eip` aux IPs de vos utilisateurs
3. **Utiliser des clés SSH fortes** : Utilisez des clés RSA 4096 bits minimum
4. **Activer l'authentification à deux facteurs** : Dans les paramètres d'Uptime Kuma
5. **Sauvegardes régulières** : Sauvegardez le dossier `/app/data` (Docker) ou `~/uptime-kuma/data` (PM2)
6. **Certificat SSL** : Utilisez HTTPS avec Let's Encrypt pour chiffrer les communications
7. **Mises à jour régulières** : Maintenez Uptime Kuma et le système d'exploitation à jour

### Vérification du Security Group

```bash
# Vérifier les règles du Security Group
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=kuma_nsg_ec2_public_access" \
  --region eu-west-3
```

## 🐛 Dépannage

### Le port 22 est "filtered"

**Cause** : Mauvaise configuration du Security Group egress

**Solution** : Vérifiez que la ressource `aws_vpc_security_group_egress_rule` (pas `ingress_rule`) est correctement définie dans `main.tf`

### Impossible d'accéder à Uptime Kuma

**Vérifications** :
1. Le service est-il démarré ?
   ```bash
   docker ps  # Pour Docker
   pm2 status  # Pour PM2
   ```

2. Le port est-il ouvert ?
   ```bash
   sudo netstat -tlnp | grep 3001
   ```

3. La route table est-elle correcte ?
   ```bash
   terraform state show aws_route_table.kuma_rt_public
   ```

### Problèmes de connexion SSH

```bash
# Vérifier les logs de connexion
ssh -vvv -i ~/.ssh/kuma_admin_key admin@<ELASTIC_IP>

# Vérifier les permissions de la clé
chmod 600 ~/.ssh/kuma_admin_key
```

### L'instance EC2 ne démarre pas

```bash
# Vérifier les logs système de l'instance
aws ec2 get-console-output --instance-id <INSTANCE_ID> --region eu-west-3
```

## 🤝 Contribuer

Les contributions sont les bienvenues ! Pour contribuer :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📝 Ressources

- [Documentation officielle Uptime Kuma](https://github.com/louislam/uptime-kuma/wiki)
- [Documentation Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Bonnes pratiques AWS](https://aws.amazon.com/architecture/well-architected/)
- [Guide de sécurité EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security.html)

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

Uptime Kuma est également sous licence MIT - voir [louislam/uptime-kuma](https://github.com/louislam/uptime-kuma) pour plus de détails.

## ✨ Remerciements

- [Louis Lam](https://github.com/louislam) pour Uptime Kuma
- La communauté Terraform
- La communauté AWS

---

**Note** : Ce projet est maintenu de manière indépendante et n'est pas officiellement affilié à Uptime Kuma ou AWS.

Pour toute question ou problème, n'hésitez pas à ouvrir une [issue](https://github.com/w0dd3n/aws/issues) sur GitHub.