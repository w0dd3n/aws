# Uptime Kuma avec Docker et NGINX SSL/TLS sur AWS

Cette configuration Terraform déploie automatiquement Uptime Kuma avec NGINX en reverse proxy et terminaison SSL/TLS.

## 📋 Prérequis

- Terraform >= 1.0
- AWS CLI configuré avec vos credentials
- Un certificat SSL/TLS au format PEM (contenant le certificat + la clé privée)
- Une paire de clés SSH

## 🔐 Préparation du certificat SSL

Votre fichier `certificate.pem` doit contenir **à la fois** le certificat et la clé privée dans cet ordre :

```pem
-----BEGIN CERTIFICATE-----
[Votre certificat]
-----END CERTIFICATE-----
-----BEGIN PRIVATE KEY-----
[Votre clé privée]
-----END PRIVATE KEY-----
```

### Générer un certificat auto-signé (pour test uniquement)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certificate.pem -out certificate.pem \
  -subj "/C=FR/ST=IDF/L=Paris/O=MyOrg/CN=uptime-kuma.local"
```

### Utiliser un certificat Let's Encrypt existant

```bash
cat /etc/letsencrypt/live/votre-domaine/fullchain.pem \
    /etc/letsencrypt/live/votre-domaine/privkey.pem > certificate.pem
```

## 🚀 Installation

### 1. Clonez ou créez la structure du projet

```bash
mkdir uptime-kuma-terraform
cd uptime-kuma-terraform
```

### 2. Placez vos fichiers

```
uptime-kuma-terraform/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── certificate.pem      # Votre certificat SSL
└── ssh_key.pub          # Votre clé publique SSH
```

### 3. Configurez vos variables

Copiez le fichier exemple et modifiez-le :

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Variables importantes à ajuster :**

- `allowed_mgmt_eip` : Votre IP publique pour SSH (récupérez-la avec `curl ifconfig.me`)
- `allowed_clients_eip` : IPs autorisées à accéder à Uptime Kuma (ou `0.0.0.0/0` pour tous)
- `ssl_cert_path` : Chemin vers votre certificat PEM
- `pubkey_path` : Chemin vers votre clé publique SSH

### 4. Initialisez Terraform

```bash
terraform init
```

### 5. Vérifiez le plan

```bash
terraform plan
```

### 6. Déployez l'infrastructure

```bash
terraform apply
```

Confirmez avec `yes` quand demandé.

## 🎯 Accès à Uptime Kuma

Après environ **2-3 minutes** (le temps que cloud-init termine l'installation), accédez à :

```
https://[IP_PUBLIQUE_AFFICHEE]
```

**Note :** Si vous utilisez un certificat auto-signé, votre navigateur affichera un avertissement de sécurité. Vous pouvez l'accepter pour continuer.

### Première connexion

1. Vous serez redirigé vers la page de configuration initiale
2. Créez votre compte administrateur
3. Configurez vos premiers monitors !

## 🏗️ Architecture déployée

### Composants créés

- **VPC** avec Internet Gateway
- **Subnet public** dans la zone `${region}a`
- **Security Group** avec règles pour SSH (22), HTTP (80) et HTTPS (443)
- **EC2 instance** t2.medium (2 vCPU, 4 GB RAM, 10 GB de disque)
- **Elastic IP** (IP publique fixe)

### Services installés automatiquement

1. **Docker & Docker Compose** (dernière version)
2. **Uptime Kuma** (v1) via conteneur Docker
3. **NGINX** configuré comme reverse proxy avec SSL/TLS

### Configuration Docker Compose

Le fichier généré contient tous les paramètres optimisés :

```yaml
- Image: louislam/uptime-kuma:1
- Port: 127.0.0.1:3001 (non exposé publiquement)
- Volume: /opt/uptimekuma/data (persistance des données)
- Timezone: Europe/Paris
- Network: kuma_network (bridge)
- Healthcheck: toutes les 30 secondes
- Logging: rotation automatique (10MB max, 3 fichiers)
- Restart: always
```

### Configuration NGINX

- **Redirection HTTP → HTTPS** automatique
- **TLS 1.2 et 1.3** avec chiffrements modernes
- **WebSocket support** (essentiel pour Uptime Kuma)
- **Headers de sécurité** (HSTS, X-Frame-Options, etc.)
- **Timeouts optimisés** pour les connexions longues

## 📁 Persistance des données

Les données d'Uptime Kuma sont stockées dans `/opt/uptimekuma/data` sur l'hôte. Ce répertoire contient :

- Base de données SQLite
- Configuration des monitors
- Historique des vérifications
- Paramètres de notification

**⚠️ Sauvegardez régulièrement ce répertoire !**

```bash
# Connexion SSH
ssh -i votre_cle_privee admin@[IP_PUBLIQUE]

# Sauvegarde
sudo tar -czf uptime-kuma-backup-$(date +%Y%m%d).tar.gz /opt/uptimekuma/data
```

## 🔧 Dépannage

### Vérifier le statut des services

```bash
# SSH vers l'instance
ssh -i votre_cle_privee admin@[IP_PUBLIQUE]

# Vérifier Docker
sudo docker ps

# Vérifier les logs Uptime Kuma
sudo docker logs uptime-kuma

# Vérifier NGINX
sudo systemctl status nginx
sudo nginx -t

# Vérifier les logs NGINX
sudo tail -f /var/log/nginx/error.log
```

### Le conteneur ne démarre pas

```bash
# Vérifier les logs cloud-init
sudo cat /var/log/cloud-init-output.log

# Redémarrer manuellement
cd /opt/uptime-kuma
sudo docker compose down
sudo docker compose up -d
```

### Erreur de certificat SSL

Vérifiez que votre fichier PEM contient bien les deux parties :

```bash
# Doit afficher le certificat ET la clé privée
openssl x509 -in certificate.pem -text -noout
openssl rsa -in certificate.pem -check
```

### WebSocket ne fonctionne pas

Le support WebSocket est **critique** pour Uptime Kuma. Vérifiez la configuration NGINX :

```bash
sudo cat /etc/nginx/sites-enabled/uptime-kuma | grep -A 3 "Upgrade"
```

Vous devez voir :
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

## 🔄 Mise à jour d'Uptime Kuma

```bash
# SSH vers l'instance
ssh -i votre_cle_privee admin@[IP_PUBLIQUE]

# Mettre à jour l'image
cd /opt/uptime-kuma
sudo docker compose pull
sudo docker compose up -d
```

## 🗑️ Destruction de l'infrastructure

```bash
terraform destroy
```

**⚠️ Attention :** Cela supprimera définitivement toutes les ressources et données !

## 📚 Ressources

- [Documentation Uptime Kuma](https://github.com/louislam/uptime-kuma)
- [Configuration reverse proxy](https://github.com/louislam/uptime-kuma/wiki/Reverse-Proxy)
- [Docker Hub - Uptime Kuma](https://hub.docker.com/r/louislam/uptime-kuma)

## 🆘 Support

En cas de problème :

1. Consultez les logs (`/var/log/cloud-init-output.log`)
2. Vérifiez les outputs Terraform
3. Testez la connectivité réseau (Security Groups)
4. Validez votre certificat SSL

## 🔒 Sécurité

- Ne commitez **jamais** vos certificats SSL ou clés privées dans Git
- Utilisez `.gitignore` pour exclure les fichiers sensibles
- Restreignez les `allowed_clients_eip` aux IPs nécessaires
- Renouvelez régulièrement vos certificats SSL
- Activez l'authentification à deux facteurs dans Uptime Kuma

## 📝 License

Configuration Terraform sous votre propre licence.
Uptime Kuma est sous licence MIT.