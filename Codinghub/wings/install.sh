#!/bin/bash
set -e

# --- CONFIG & SEMA UI COLORS ---
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GRAY='\033[38;5;242m'
WHITE='\033[38;5;255m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
GOLD='\033[38;5;214m'
NC='\033[0m'

# --- UI ELEMENTS ---
CHECK="✔"
ARROW="➜"

# --- HELPER FUNCTIONS ---
show_header() {
    clear
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${CYAN}🦅 PTERODACTYL WINGS INSTALLER${NC} ${GRAY}v16.0${NC}       ${GRAY}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
}

print_step() {
    echo -e "\n  ${PURPLE}[$1]${NC} ${WHITE}$2${NC}"
}

status_log() {
    echo -e "  ${GRAY}├─${NC} ${ARROW} $1..."
}

success_log() {
    echo -e "  ${GRAY}└─${NC} ${GREEN}$CHECK $1${NC}"
}

error_exit() {
    echo -e "\n  ${RED}✘ CRITICAL ERROR: $1${NC}"
    exit 1
}

# --- INITIALIZATION ---
show_header
if [ "$EUID" -ne 0 ]; then
    error_exit "Root privileges required."
fi

# 1. Docker Environment
print_step "1/6" "DOCKER ENGINE DEPLOYMENT"
status_log "Downloading Docker"
curl -sSL https://get.docker.com/ | CHANNEL=stable bash /dev/null 2>&1
status_log "Enabling service"
sudo systemctl enable --now docker > /dev/null 2>&1
success_log "Docker Environment Ready"

# 2. System Optimization
print_step "2/6" "KERNEL & GRUB TUNING"
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    print_status "Updating GRUB"
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' $GRUB_FILE
    sudo update-grub > /dev/null 2>&1
fi
    success_log "Kernel Parameters Updated"
else
    success_log "Grub not found, skipping patch"
fi

# 3. Wings Binary
print_step "3/6" "WINGS CORE DEPLOYMENT"
status_log "Creating directories"
sudo mkdir -p /etc/pterodactyl
status_log "Detecting architecture"
ARCH=$(uname -m)
[ "$ARCH" == "x86_64" ] && ARCH="amd64" || ARCH="arm64"
echo -e "  ${GRAY}│${NC}  ${PURPLE}${NC}${WHITE}${BG_SHADE} ARCH: $ARCH ${NC}${PURPLE}${NC}"

status_log "Fetching binary"
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH" > /dev/null 2>&1
chmod u+x /usr/local/bin/wings
success_log "Wings Binary vLatest Active"

# 4. Service Configuration
print_step "4/6" "SYSTEMD INTEGRATION"
status_log "Generating wings.service"
cat <<EOF > /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now wings
success_log "Service Configured & Linked"

# 5. SSL Layer
print_step "5/6" "SECURITY & SSL GENERATION"
status_log "Self-signing certificate"
mkdir -p /etc/certs/wing
cd /etc/certs/wing
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Sema Node SSL" \
-keyout privkey.pem -out fullchain.pem > /dev/null 2>&1
success_log "SSL Certificate Generated"

# 6. Helper Utility
print_step "6/6" "NODE UTILITY COMMANDS"
status_log "Injecting 'wing' helper"
cat <<'EOF' > /usr/local/bin/wing
#!/bin/bash
echo -e "\n  \033[1;38;5;141m🦅 WINGS NODE HELPER\033[0m"
echo -e "  \033[0;38;5;242m├─ start   :\033[0m systemctl start wings"
echo -e "  \033[0;38;5;242m├─ stop    :\033[0m systemctl stop wings"
echo -e "  \033[0;38;5;242m├─ status  :\033[0m systemctl status wings"
echo -e "  \033[0;38;5;242m└─ logs    :\033[0m journalctl -u wings -f\n"
EOF
chmod +x /usr/local/bin/wing
success_log "Helper Command Link: 'wing'"

# --- FINAL DASHBOARD ---
echo -e "\n${GREEN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│${NC}  ${WHITE}NODE DEPLOYMENT SUCCESSFUL!${NC}                             ${GREEN}│${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────┘${NC}"
echo -e "  ${CYAN}SYSTEM READY${NC}"
echo -e "  ${GRAY}├─ Wings binary :${NC} /usr/local/bin/wings"
echo -e "  ${GRAY}├─ SSL Path     :${NC} /etc/certs/wing/"
echo -e "  ${GRAY}└─ Utility      :${NC} Type ${GOLD}'wing'${NC} for node commands"
echo -e "${GRAY}────────────────────────────────────────────────────────────${NC}\n"
