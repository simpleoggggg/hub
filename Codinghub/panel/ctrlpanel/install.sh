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

echo -e "${YELLOW}Enter your domain or IP (example: panel.domain.com or 1.2.3.4)${NC}"

while true; do

read -p "➤ Domain/IP: " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    print_error "Domain or IP cannot be empty"

# check domain
elif echo "$DOMAIN_NAME" | grep -qE '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$'; then
    break

# check IPv4
elif echo "$DOMAIN_NAME" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    break

else
    print_error "Invalid domain or IP format"
fi

done

print_success "Host set: $DOMAIN_NAME"

# ===============================
# OS Detect
# ===============================
# OS detect
source /etc/os-release

if [[ "$ID" == "ubuntu" ]]; then
    echo "Ubuntu detected"
    ash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/panel/ctrlpanel/Ubuntu.sh)

elif [[ "$ID" == "debian" ]]; then
    echo "Debian detected"
    bash <(curl -s https://raw.githubusercontent.com/nobita329/hub/refs/heads/main/Codinghub/panel/ctrlpanel/Debian.sh)

else
    echo "Unsupported OS: $ID"
fi

systemctl enable --now mariadb

# ===============================
# Install Composer
# ===============================

print_status "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
# ===============================
# Download CtrlPanel
# ===============================

print_status "Downloading CtrlPanel..."

mkdir -p /var/www/ctrlpanel && cd /var/www/ctrlpanel
git clone https://github.com/Ctrlpanel-gg/panel.git ./

# ===============================
# Database Setup
# ===============================

print_status "Configuring database..."

DB_NAME=ctrlpanel
DB_USER=ctrlpaneluser
DB_PASS=ctrlpanel
mariadb -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mariadb -e "CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';"
mariadb -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'127.0.0.1';"
mariadb -e "FLUSH PRIVILEGES;"

# ===============================
# Install Panel
# ===============================

print_status "Installing dependencies..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

# ===============================
# Permissions
# ===============================

php artisan storage:link
chown -R www-data:www-data /var/www/ctrlpanel/
chmod -R 755 storage/* bootstrap/cache/

# ===============================
# Cron Job
# ===============================

print_status "Adding cron..."
apt install -y cron
systemctl enable --now cron
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/ctrlpanel/artisan schedule:run >> /dev/null 2>&1") | crontab -

# ===============================
# Queue Worker
# ===============================

print_status "Creating queue worker..."

cat >/etc/systemd/system/ctrlpanel.service <<EOF
# Ctrlpanel Queue Worker File
# ----------------------------------

[Unit]
Description=Ctrlpanel Queue Worker

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/ctrlpanel/artisan queue:work --sleep=3 --tries=3
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
sudo systemctl enable --now ctrlpanel.service

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
rm /etc/nginx/sites-enabled/default
print_status "Configuring Nginx..."

cat >/etc/nginx/sites-available/ctrlpanel.conf <<EOF
server {
    # Redirect HTTP to HTTPS
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    # Main HTTPS server
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    root /var/www/ctrlpanel/public;
    index index.php;

    access_log /var/log/nginx/ctrlpanel.app-access.log;
    error_log  /var/log/nginx/ctrlpanel.app-error.log error;

    # Allow large upload sizes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # SSL Configuration
    ssl_certificate /etc/certs/ctrlpanel/fullchain.pem;
    ssl_certificate_key /etc/certs/ctrlpanel/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
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
