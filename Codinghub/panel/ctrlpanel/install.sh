#!/bin/bash

# ===============================
# Colors
# ===============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${CYAN}[➤] $1${NC}"; }
print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }

get_web_user() {
if id www-data &>/dev/null; then
echo "www-data"
elif id nginx &>/dev/null; then
echo "nginx"
else
echo "www-data"
fi
}

clear

echo -e "${BLUE}"
echo " ██████╗████████╗██████╗ ██╗     ██████╗  █████╗ ███╗   ██╗███████╗██╗"
echo "██╔════╝╚══██╔══╝██╔══██╗██║     ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║"
echo "██║        ██║   ██████╔╝██║     ██████╔╝███████║██╔██╗ ██║█████╗  ██║"
echo "██║        ██║   ██╔══██╗██║     ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║"
echo "╚██████╗   ██║   ██║  ██║███████╗██║     ██║  ██║██║ ╚████║███████╗███████╗"
echo " ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
echo -e "${NC}"

echo -e "${GREEN}CtrlPanel Auto Installer${NC}"
echo ""

# ===============================
# Domain Input
# ===============================

echo -e "${YELLOW}Enter your domain (example: panel.domain.com)${NC}"

while true; do

read -p "➤ Domain: " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
print_error "Domain cannot be empty"

elif ! echo "$DOMAIN_NAME" | grep -qE '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
print_error "Invalid domain format"

else
break
fi

done

print_success "Domain set: $DOMAIN_NAME"

# ===============================
# OS Detect
# ===============================
# OS detect
source /etc/os-release

if [[ "$ID" == "ubuntu" ]]; then
    echo "Ubuntu detected"
    bash Ubuntu

elif [[ "$ID" == "debian" ]]; then
    echo "Debian detected"
    bash Debian

else
    echo "Unsupported OS: $ID"
fi


# ===============================
# Install Composer
# ===============================

print_status "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# ===============================
# Download CtrlPanel
# ===============================

print_status "Downloading CtrlPanel..."

mkdir -p /var/www/ctrlpanel
cd /var/www/ctrlpanel
git clone https://github.com/Ctrlpanel-gg/panel.git ./

# ===============================
# Database Setup
# ===============================

print_status "Configuring database..."

DB_NAME=ctrlpanel
DB_USER=ctrlpaneluser
DB_PASS=ctrlpanel

systemctl enable --now mariadb

mariadb -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mariadb -e "CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';"
mariadb -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'127.0.0.1';"
mariadb -e "FLUSH PRIVILEGES;"

# ===============================
# Install Panel
# ===============================

print_status "Installing dependencies..."

COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

cp .env.example .env

php artisan key:generate

php artisan migrate --force

php artisan storage:link

# ===============================
# Permissions
# ===============================

WEB_USER=$(get_web_user)

chown -R $WEB_USER:$WEB_USER /var/www/ctrlpanel

chmod -R 755 storage bootstrap/cache

# ===============================
# Cron Job
# ===============================

print_status "Adding cron..."

CRON_JOB="* * * * * php /var/www/ctrlpanel/artisan schedule:run >> /dev/null 2>&1"

(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

systemctl enable --now cron

# ===============================
# Queue Worker
# ===============================

print_status "Creating queue worker..."

cat >/etc/systemd/system/ctrlpanel.service <<EOF
[Unit]
Description=CtrlPanel Queue Worker

[Service]
User=$WEB_USER
Group=$WEB_USER
Restart=always
ExecStart=/usr/bin/php /var/www/ctrlpanel/artisan queue:work --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ctrlpanel

# ===============================
# SSL Certificate
# ===============================

print_status "Generating SSL..."

mkdir -p /etc/certs/ctrlpanel
cd /etc/certs/ctrlpanel

openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=$DOMAIN_NAME" \
-keyout privkey.pem -out fullchain.pem

# ===============================
# Nginx Config
# ===============================

print_status "Configuring Nginx..."

cat >/etc/nginx/sites-available/ctrlpanel.conf <<EOF
server {
listen 80;
server_name $DOMAIN_NAME;
return 301 https://\$host\$request_uri;
}

server {

listen 443 ssl http2;

server_name $DOMAIN_NAME;

root /var/www/ctrlpanel/public;

index index.php;

ssl_certificate /etc/certs/ctrlpanel/fullchain.pem;
ssl_certificate_key /etc/certs/ctrlpanel/privkey.pem;

location / {
try_files \$uri \$uri/ /index.php?\$query_string;
}

location ~ \.php\$ {

include fastcgi_params;

fastcgi_pass unix:/run/php/php8.3-fpm.sock;

fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;

}

}
EOF

ln -s /etc/nginx/sites-available/ctrlpanel.conf /etc/nginx/sites-enabled/

nginx -t

systemctl restart nginx

# ===============================
# Finish
# ===============================

echo ""
echo -e "${GREEN}Installation Completed!${NC}"
echo ""
echo -e "${BLUE}Panel URL:${NC} https://$DOMAIN_NAME"
echo -e "${BLUE}Panel Path:${NC} /var/www/ctrlpanel"
echo ""
